# 执行工作单与依赖

**2026-09-17 执行规则更新：** 默认采用 [智能体自主研发合同](22_agent_local_execution.md)。项目责任由智能体承担；外部 CA、证明人、时间戳、ACK 或签发材料不再是主线前置条件。本文中的历史 external/trusted/authority 限制按该合同解释；保留实际输入、语义、数值与工程检查，不改写旧证据。

AD-20 chain note: UP2-00 has an independent r18 accepted_limited local result for actual-A N01/N02 schema/value projection; N07/N08 and N09 have separate local accepted_limited contract archives that do not count as formal B04 receipts; the total gate remains review_pending/accepted=false with all 50 formal B04 receipts pending; UP1-04B remains planned and still owns B00 F0-F5, formal B04 mutations, receipts, checker, and two-process replay.

## 2026-09-18 索引同步状态（非运行验收）

本工作单当前索引基线为 HEAD `348b061`（`348b0611b9c8afd20bab0fb706528733c3fa0d7d`）；后续提交会再刷新。下列记录是静态、合同或屏幕记录，不是完成百分比，也不得替代原始工单的退出门或关闭 UP 标签：

| 记录 | 提交 | 当前边界 |
|---|---|---|
| T0 LocalV1 | `87f0263` | committed |
| T0 authority recheck | `a7b6362` | static 125/125；R12 `performance_gate_timeout`，0/25；`NO-GO`，T1 not started |
| UP2 spatial transfer | `ca5fef9` | 70/70 `contract_only` |
| UP3 composition solve plan | `a1ad8cc` | 161/161 `contract_only` |
| UP4 SHIR | `5d9d651` | 547/547 `prepared_not_measured` |
| UP4 engineering bridge | `5ea78c0` | 189/189 `contract_only` |
| UP5 conditional egraph | `cd52ee3` | `contract_only` conditional egraph；不关闭标签 |
| UP5 bounded structure | `f9612bd` | 94/94 `contract_only` |
| UP6 final ledger | `67a4e87` | 123/123 `contract_only`；no final authority |
| UP2 executable screen | `348b061` | 68/68 `manufactured_numerical_screen` |

T0 authority recheck 因 R12 `performance_gate_timeout` 为 `NO-GO`，T1 尚未开始。上述记录没有 provider/physics Julia/DESC runtime credit、物理、工程或 final authority 信用；本波次 focused Julia contract tests 已运行，仅作合同证据。`R01–R10` 仍 `pending`，`L4=0`，parent goal 仍 open，UP labels 未由这些 receipts 关闭。清理备注：五个未跟踪 `pyc` 已移除；`runs`、`tmp`、evidence 和 protected dirty 状态保留。未运行的切片不得写成完成，旧 runs 和工作树 dirty 文件不属于本状态同步。

## 读取与派单合同

先读 00、README、14 和该任务的技术章。下文写入范围是组件归属建议，正式派单必须展开为精确文件列表并冻结，禁止两人重叠写入。新类型、脚本和模块是拟建；现有文件路径由 UP0 核对。所有任务都由 Luna（high）执行，不同 Luna 复核，Sol 只作最高层安排和决策。

每单交付 `docs/implementation/<task-id>/acceptance.md` 和 `evidence_manifest.json`，包含输入/代码/环境版本、真实命令/退出码、日志与产物哈希、数值/物理/执行分类、负控制、独立评审和尚未覆盖范围。未接受前可记录进展，但不得标成已验收档案。

UP0-02 冻结精确命令与容差后才能开始相应执行。不能直接运行文档中的拟建函数名。组件作者先创建入口和测试，集成者核对命令存在、参数与输出路径后写 execution recipe，再排重计算。可用的现有软件回归入口（不是新增能力验收）包括：

```powershell
julia --project=. scripts/test_runtime_v4.jl core archive
julia --project=. test/runtime_v4_algebraic_generation_tests.jl
```

两条入口均已从当前源码核对；接手基线若有变化，须重新定位测试并修订 recipe，不能默认成功。新能力测试必须覆盖该工单正负例，不可仅反复运行旧核心测试。

## 调度总表

旁路 W24-G2-CHILD-R2 仅有 `sealed_execution_status_snapshot` 的有限归档，`comparability_status=changes_requested`；该快照不构成 W24 物理、工程、provider、可信候选或 R01–R10 信用，也不改变 UP0–UP6 DAG。

| ID | 阶段任务 | 前置 | 可选 |
|---|---|---|---|
| [UP0-01](#up0-01) | 刷新基线与中断运行审计 | 无 | 否 |
| [UP0-02](#up0-02) | 冻结跨层合同与验收协议 | UP0-01 | 否 |
| [UP1-01](#up1-01) | G1 可组合机制和闭合 | UP0-02 | 否 |
| [UP1-02](#up1-02) | G2 一般空间和场合同 | UP0-02 | 否 |
| [UP1-03](#up1-03) | G3 资源与实现控制合同 | UP0-02 | 否 |
| [UP1-04A](#up1-04a) | 共享入口迁移与 G2 ref 重建 | UP1-01, UP1-02, UP1-03 | 否 |
| [UP2-01-G1-DIFFUSION-V1](#up2-01-g1-diffusion-v1) | G1 actual-candidate variable-coefficient diffusion schema | UP1-01, UP1-02, UP1-03 | 否 |
| [UP2-01-G2-METRIC-BOUNDARY-V1](#up2-01-g2-metric-boundary-v1) | G2 chart-to-metric mesh and executable face ownership schema | UP1-01, UP1-02, UP1-03 | 否 |
| [UP2-01-G3-SOURCE-FEEDBACK-V1](#up2-01-g3-source-feedback-v1) | G3 same-candidate source and feedback authority schema | UP1-01, UP1-02, UP1-03 | 否 |
| [UP1-04A-VNEXT-G3-BINDING-EDIT-PREC](#up1-04a-vnext-g3-binding-edit-prec) | G3 candidate-owned binding editable sibling precursor | UP2-01-G3-SOURCE-FEEDBACK-V1 | 否 |
| [UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC](#up1-04a-vnext-g3-realization-edit-prec) | G3 realization source-edit precursor | UP2-01-G3-SOURCE-FEEDBACK-V1 | 否 |
| [UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC](#up1-04a-vnext-g3-control-edit-prec) | G3 control source-edit precursor | UP2-01-G3-SOURCE-FEEDBACK-V1 | 否 |
| [UP1-04A-VNEXT-T0](#up1-04a-vnext-t0) | VNEXT V1 declaration transport and exact semantic bundle | UP1-04A, UP2-01-G1-DIFFUSION-V1, UP2-01-G2-METRIC-BOUNDARY-V1, UP2-01-G3-SOURCE-FEEDBACK-V1 | 否 |
| [UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC](#up1-04a-vnext-t0-authority-recheck-prec) | T0 output declaration authority recheck gate | UP1-04A-VNEXT-T0 | 否 |
| [UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC](#up1-04a-vnext-parent-baseline-bind-prec) | G1/G2 V1 parent-baseline binding and typed-absence prerequisite | UP1-01, UP1-02, UP1-03 | 否 |
| [UP1-04A-VNEXT-T1](#up1-04a-vnext-t1) | CandidateStatePackageV5Next and VNEXT integrator | UP1-04A-VNEXT-T0, UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC | 否 |
| [UP1-04A-VNEXT-T2](#up1-04a-vnext-t2) | VNEXT E0/G-I1A/E1/E2/UP2 identity and receipt rebinding | UP1-04A-VNEXT-T1 | 否 |
| [UP1-04A-VNEXT](#up1-04a-vnext) | T2 后新候选综合冻结与独立验收汇聚门 | UP1-04A-VNEXT-T2 | 否 |
| [UP2-00](#up2-00) | contract-only typed precompiler schema/validator | UP1-04A-VNEXT | 否 |
| [UP1-04B](#up1-04b) | B00/B04 正式冻结、checker 与双进程复放 | UP2-00 | 否 |
| [UP1-04](#up1-04) | Genome 迁移与入口集成总门 | UP1-04B | 否 |
| [UP2-01](#up2-01) | 声明驱动的物理方程编译 | UP1-04 | 否 |
| [UP2-02](#up2-02) | 空间物化、离散组装与一般入口 | UP2-01 | 否 |
| [UP2-03](#up2-03) | 拓扑传递与外部区域闭合 | UP2-02 | 否 |
| [UP2-04](#up2-04) | 耦合求解、约束与集成 | UP2-03 | 否 |
| [UP2-05](#up2-05) | 成熟物理模块及 backend 能力登记 | UP2-04 | 否 |
| [UP3-01](#up3-01) | 自动组合执行矩阵 | UP2-05 | 否 |
| [UP3-02](#up3-02) | 留出组合与通用性反证测试 | UP3-01 | 否 |
| [UP3-03](#up3-03) | 可选的受验证基降维 | UP3-02 | 是 |
| [UP4-01](#up4-01) | 源与硬件的逆向 realization | UP3-02 | 否 |
| [UP4-02](#up4-02) | 热、材料、结构与控制回代 | UP4-01 | 否 |
| [UP4-03](#up4-03) | 真实参考表示与隐参逆恢复 | UP4-02 | 否 |
| [UP4-04](#up4-04) | 逆实现闭环集成验收 | UP4-03 | 否 |
| [UP5-01](#up5-01) | 条件 e-graph 接入 | UP4-04 | 否 |
| [UP5-02](#up5-02) | 丰富 typed edits 与物理反馈 | UP5-01 | 否 |
| [UP5-03](#up5-03) | 有界比较 campaign 后扩容 | UP5-02 | 否 |
| [UP6-01](#up6-01) | 补齐整装必需物理和工程覆盖 | UP5-03 | 否 |
| [UP6-02](#up6-02) | 独立 VVUQ 与整装净输出 | UP6-01 | 否 |
| [UP6-03](#up6-03) | 原创性、独立复放与父目标关账 | UP6-02 | 否 |

UP1-01/02/03 可以在共同合同冻结后并行；其余有依赖的编辑顺序执行。所有重数值运行共用串行队列。UP3-03 是可选加速研究，后续主链不依赖它。UP6 的后置关账不阻止较早准备独立数据和适配器；有提前工作时必须拆成显式、无循环依赖的子单，由 Sol 更新清单，不能悄悄提前声称阶段通过。

每单只执行其声明范围内适用的基准子协议：UP4-01 使用 B07A 源硬件逆设计，UP4-03 使用 B07B 真实参考隐参逆恢复；B07A 不提供 R02 信用。B06a 审查外部空间域、B06b 审查场基截断、B06c 仅在实际使用 ROM 时执行。UP0-02 冻结各单的适用子协议和能力范围，不能因共用 B06/B07 编号引入隐式循环依赖；最终 UP6 仍须覆盖全部实际使用能力与原 R01–R10。

## 工单细节

<a id="up0-01"></a>

### UP0-01 刷新基线与中断运行审计

当前状态：`accepted`（仅当前基线、脏文件保护、W22–W24 审计与 R01–R10 状态账本）；归档：[UP0-01 acceptance](../implementation/UP0-01/acceptance.md)。B00 新鲜双进程、标签擦除和置换验证仍为 `pending`。

- 前置：无。
- 技术章：[13_acceptance_benchmarks_and_evidence.md](13_acceptance_benchmarks_and_evidence.md)；验收基准：B00，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：当前 HEAD、git diff/status；W22–W24 task_queue 与实际 checkpoints；旧验收 ledger。
- 写入范围：只读源码、历史 runs；新建 docs/implementation/UP0-01/，不修改旧队列。

执行步骤：

1. 记录 tracked/untracked 脏文件的路径与 SHA256；逐项区分当前源码与历史报告。
2. 核对 W24 子任务检查点和日志，按实际进程命令/启动时间识别运行状态；不以旧 PID 为准，不自动重跑或终止。
3. 建立 R01–R10 当前状态、剩余义务和 source/artifact 索引，报告引用失效及程序中断。

退出门：

- 保护清单可复算；没有用测试/runner exit 0覆盖物理失败；每项事实能定位 artifact。
- 输出基线和可继续工单，独立复核者抽查 W24 身份与退出码。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up0-02"></a>

### UP0-02 冻结跨层合同与验收协议

当前状态：`accepted`（前置 UP0-01 已接受），范围仅为 `accepted_scope=pre_result_contract_design`；`B00=false`、`B04=false`、`physical=false`，不表示执行、schema/provider hash 或物理证据已存在。归档：[UP0-02 acceptance](../implementation/UP0-02/acceptance.md)。

- 前置：UP0-01。
- 技术章：[00_normative_contracts_and_state_model.md](00_normative_contracts_and_state_model.md)；验收基准：B00、B04，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：00、10–13、旧构造器/注册表、原 R01–R10；UP0-01 基线。
- 写入范围：当前规划的版本/协议文件；拟建受版本控制的 schema/fixture 文件，文件清单先由 Sol 冻结。

执行步骤：

1. 定义 G1 方程/G2 空间/G3 资源的单一所有权；将各章拟议类型名整理成同一命名和版本表。
2. 冻结 capability axes、状态映射、lowering 接口、迁移失效规则与最小测试配置。
3. 预注册基准量纲、归一化、解析/MMS oracle、阈值、留出集、数值预算与 claim ceiling；评审后再实现。

退出门：

- 三层无重复方程/账本所有权；旧 hash 域不变；目标范围不缩减。
- 每个 UP1/UP2 工单都有精确输入输出与合法/非法例；阈值并非看结果后选择。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up1-01"></a>

### UP1-01 G1 可组合机制和闭合

当前状态：`accepted`，范围仅为 `g1_typed_mechanism_mimo_closure_candidate_owned_structural_contract`；归档：[UP1-01 acceptance](../implementation/UP1-01/acceptance.md)、[evidence manifest](../implementation/UP1-01/evidence_manifest.json)。r13 focused test 为 68/68 软件合同证据；`B00=false`、`B04=false`、`provider=false`、`mesh=false`、`engineering=false`、`physical=false`，不授予 R01–R10 信用。

- 前置：UP0-02。
- 技术章：[10_genome_upgrade_execution.md](10_genome_upgrade_execution.md)；验收基准：B01、B04，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：G1 文档；TypedAST、OperatorHypergraph、MechanismGenomePayload；冻结算子配置。
- 写入范围：G1 语义/构造器及专属测试；不写 G2/G3 或公共入口。

执行步骤：

1. 把算子签名、state/parameter 区分、单位、时间、效应、导数和 closure 条件编成可检查结构。
2. 将旧有限上限保留为旧 profile；新有限 GrammarProfile 管理可扩展组合规模与成本。
3. 实现选定组合核和缺闭合/单位错误/效应重复记账负例；导出可供 equation lowering 的数学语义。

退出门：

- 增加 AST/机制组合能改变可执行方程；缺 closure 不会默认为通过。
- 多根/MIMO 与守恒 occurrence 绑定保持正确；基因字段规模与网格 DOF 分开。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up1-02"></a>

### UP1-02 G2 一般空间和场合同

当前状态：`accepted`，范围仅为 `axis_aligned_rational_3d_g2_structural_contract`；归档：[UP1-02 acceptance](../implementation/UP1-02/acceptance.md)、[evidence manifest](../implementation/UP1-02/evidence_manifest.json)。r7 focused test 为 124/124 软件合同证据；`B04=false`、`mesh=false`、`physical=false`，provider deferred，未授予工程或 R01–R10 信用。UP1-04 仍须完成三层 Genome 迁移与共享入口集成。

- 前置：UP0-02。
- 技术章：[10_genome_upgrade_execution.md](10_genome_upgrade_execution.md)；验收基准：B04、B05、B06，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：G2 文档；FieldGeometrySpatialSupport/FieldPrograms；旧固定两区域网格声明。
- 写入范围：G2 空间合同、构造器、几何合法性与专属测试；不写共享入口。

执行步骤：

1. 定义 region/interface/boundary/chart/embedding/field space 与外域闭合选择。
2. 实现最小可物化组合的几何/拓扑检查和离散需求输出；将不可嵌入、非定向、退化网格等判为具体失败/缺口。
3. 定义静态设计拓扑编辑与时间物理拓扑事件的差异、传递量及物理模型义务。

退出门：

- 至少两种不同合法域连接声明通过同一验证入口，非法接口负例拒绝。
- 抽象合法性、几何可实现性、网格质量和物理模型可解性分开记录。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up1-03"></a>

### UP1-03 G3 资源与实现控制合同

当前状态：`accepted`，范围仅为 `g3_structural_resource_control_fault_and_standalone_feedback_contract`；归档：[UP1-03 acceptance](../implementation/UP1-03/acceptance.md)、[evidence manifest](../implementation/UP1-03/evidence_manifest.json)。`B00=false`、`B04=false`、`provider=false`、`mesh=false`、`engineering=false`、`physical=false`，不授予 R01–R10 信用；真实跨层 provenance/UP1-04 join 仍待执行。

- 前置：UP0-02。
- 技术章：[10_genome_upgrade_execution.md](10_genome_upgrade_execution.md)；验收基准：B04、B08，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：G3 文档；RealizationControlGenomeV4；既有拾取/RL与控制故障切片。
- 写入范围：G3 资源、组件、材料和控制合同及专属测试。

执行步骤：

1. 定义 effort/flow 端口、能源物质账本、回流、源逆设计变量、材料数据域和制造边界。
2. 补最小电路/热阻容量/材料核及初值、事件、故障的合同和组件验证。
3. 定义实现误差/损耗/热/形变向 G1/G2 回传的 typed 接口，暂不宣称完整逆设计完成。

退出门：

- 缺电源/回流/热沉、单位不配和重复计能均能拒绝；被动组件不能无源产能。
- 目标场不能自动生成无成本硬件；UP4 有明确可消费的逆问题合同。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up1-04a"></a>

### UP1-04A 共享入口迁移与 G2 ref 重建

当前状态：`accepted_limited`。本子单只接受共享入口、迁移 adapter 和 candidate-bound identity wiring；不能写成完整 UP1-04 acceptance。归档：[UP1-04A acceptance](../implementation/UP1-04/acceptance.md)、[独立 r12 复核](../implementation/UP1-04/independent_review_r12/acceptance.md)。

- 前置：UP1-01、UP1-02、UP1-03。
- 技术章：[10_genome_upgrade_execution.md](10_genome_upgrade_execution.md)；冻结边界：[AD-20](18_sources_and_architecture_decisions.md#ad-20)。
- 输入：已接受的三层有限合同、G2 plan 内容、UP0-02/AD-20 ref 规则和受保护 dirty inventory。
- 写入范围：UP1-04A 集成者拥有的 shared entry/package adapter 及其专属测试/归档；不写 UP1-04B suite、旧证据或无关路径。

执行步骤：

1. 从已接受 G2 plan 内容构造新的 fusionconceptai://GenomeV5/G2/ public ref，并重算 G2 与 typed package identity。
2. 将真实新 G2 ref 传入 G3 feedback/三层 package join；历史 UP1-02 urn:fusion:g2:* fixture/ref/hash 不改、不复用、不 alias。
3. 完成 shared-entry structural admission and migration receipt wiring; keep provider/mesh/physical gaps explicit。

退出门：

- UP1-04A 已以 `accepted_limited` 接受，仅证明共享入口和 contract-only identity wiring；不接受 UP1-04 总门。
- 新旧 ref/hash/evidence 隔离且 G2 ref URI、schema/canonical/profile、four axes、candidate binding exact-bound；错误映射 fail_closed，缺 authority/provider 为独立 terminal_deferred。

<a id="up2-01-g1-diffusion-v1"></a>

### UP2-01-G1-DIFFUSION-V1 G1 actual-candidate variable-coefficient diffusion schema

当前状态：`accepted`，`scope_status=accepted_local_contract`，`accepted=true`，`resolution=accepted_local_contract`；接受记录：[agent-local acceptance R1](../implementation/UP2-01-G1-DIFFUSION-V1/agent_local_acceptance_r1/acceptance.md)。这只接受 G1 declaration schema 与 candidate/source metadata contract，不是 UP2-01 执行。

- 前置：UP1-01、UP1-02、UP1-03；三者可与本单及另外两张 upstream 单并行读取。
- 输入：UP1-01/02/03 accepted contract scope plus versioned G1 declarations for candidate-owned 3-D u, K(x), f, typed GRAD/DIV, units, closure and negative controls.
- 写入范围：仅 G1-DIFFUSION-V1 schema/profile、typed receipt contract、fixture/QA/archive；不写旧 V4、旧 evidence、UP1-04B suite 或物理后端。

步骤：

1. Freeze G1 versioned schema/profile and input/output/version/hash recipe before new-candidate creation.
2. Declare candidate-owned 3-D u, positive K(x), f, typed GRAD/DIV, units, closure, applicability and source-derived negative controls.
3. Keep missing authority terminal_deferred and contradictions fail_closed; emit no compiler or physical credit.

退出门：

- 已由不同 Luna 审查与独立 agent-local wrapper replay 接受为 `accepted_local_contract`；实现和 replay 仍仅为 contract/software evidence，未取得 UP2-01 执行信用。
- G1 declaration 可以进入 T0 的实际来源/声明绑定，但 T0 必须重新读取 bytes、核对 candidate/source/receipt 并独立复算；source authority、compiler、mesh、provider、solver、numerical、physical、engineering、search、B00/B04 与 R01–R10 均保持未接受。

<a id="up2-01-g2-metric-boundary-v1"></a>

### UP2-01-G2-METRIC-BOUNDARY-V1 G2 chart-to-metric mesh and executable face ownership schema

当前状态：`accepted`，`scope_status=accepted_local_contract`，`accepted=true`，`resolution=accepted_local_contract`；接受记录：[agent-local acceptance R1](../implementation/UP2-01-G2-METRIC-BOUNDARY-V1/agent_local_acceptance_r1/acceptance.md)。这只接受 G2 declaration schema 与 candidate/source metadata contract，不是 mesh execution。

- 前置：UP1-01、UP1-02、UP1-03；三者可与本单及另外两张 upstream 单并行读取。
- 输入：UP1-01/02/03 accepted contract scope plus G2 chart, metric, mesh, basis, quadrature and executable face ownership/value declarations.
- 写入范围：仅 G2-METRIC-BOUNDARY-V1 schema/profile、typed receipt contract、fixture/QA/archive；不写旧 V4、旧 evidence、UP1-04B suite 或 mesh backend implementation。

步骤：

1. Freeze chart-to-metric, executable mesh/basis/quadrature and face ownership/value version/hash recipe before new-candidate creation.
2. Bind boundary orientation and Dirichlet/Neumann ownership to candidate identity when the new candidate is created.
3. Keep missing metric/mesh/boundary authority terminal_deferred and structural contradictions fail_closed.

退出门：

- 已由不同 Luna 独立审查与 agent-local wrapper replay 接受为 `accepted_local_contract`；`85/85` 只证明软件合同测试，不授予 mesh、守恒或物理信用。
- G2 declaration 可以进入 T0 的实际来源/声明绑定；T0 必须逐项核对真实 bytes、candidate envelope、四轴和 receipt。compiler、mesh、provider、solver、numerical、physical、engineering、search、B00/B04 与 R01–R10 均保持未接受。

<a id="up2-01-g3-source-feedback-v1"></a>

### UP2-01-G3-SOURCE-FEEDBACK-V1 G3 same-candidate source and feedback authority schema

当前状态：`accepted`，`scope_status=accepted_local_contract`，`accepted=true`，`resolution=accepted_local_contract`；接受记录：[agent-local acceptance R1](../implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/agent_local_acceptance_r1/acceptance.md)。这只接受 G3 declaration schema 与 candidate/source metadata contract，不是 source authority 或 physical feedback execution。

- 前置：UP1-01、UP1-02、UP1-03；三者可与本单及另外两张 upstream 单并行读取。
- 输入：UP1-01/02/03 accepted contract scope plus G3 source/return/heat/ledger law, feedback target, source ID, units, owner scope and agent-owned local source/declaration records.
- 写入范围：仅 G3-SOURCE-FEEDBACK-V1 schema/profile、typed receipt contract、fixture/QA/archive；不写旧 V4、旧 evidence、UP1-04B suite 或 physical backend。

步骤：

1. Freeze source-law and local semantic authority version/hash recipe before new-candidate creation.
2. Require same-candidate G1/G2 refs, source/return/heat/ledger law, units and an agent-owned local source/declaration record in the later binding receipt.
3. Keep missing local source/declaration records terminal_deferred and contradictions fail_closed; do not convert structural feedback into physical evidence.

退出门：

- 已由不同 Luna 独立审查与 agent-local wrapper replay 接受为 `accepted_local_contract`；`63/63` 只证明软件合同测试。该切片没有读取/重算 source bytes，实际 source authority 明确保持 `terminal_deferred`，由 T0/recheck 完成。
- G3 declaration 可以进入 T0 的实际来源/声明绑定；compiler、mesh、provider、solver、numerical、physical、engineering、search、B00/B04 与 R01–R10 均保持未接受。

<a id="up1-04a-vnext"></a>

### UP1-04A-VNEXT T2 后综合冻结与独立验收汇聚门

当前状态：`planned`，`scope_status=proposal`，`accepted=false`；AD-28/AD-30 仅覆盖架构、无环排期和证据边界。该节点在 T2 之后汇聚冻结和独立审查，不重复实施 T0/T1/T2；旧 UP1-04A 的 limited receipt 只保留旧候选历史范围。

- 前置：UP1-04A-VNEXT-T2。
- 输入：T2 后 `UP1-04A-VNEXT` 综合冻结的 candidate-bound package/identity receipts、T0/T1/T2 独立审查结果及冻结的 G1/G2/G3 V1 source/version/hash recipes；上游尚未冻结时只能做准备/本地 contract-only 检查，不能称 fresh candidate acceptance。
- 写入范围：仅综合冻结、独立验收汇聚和后继 handoff 记录；不重复实施 T0/T1/T2，不改旧 candidate receipt/hash、旧 V5/package 或 shared registry。

步骤：

1. Independently check the T0/T1/T2 exit records and confirm all three upstream declarations were frozen before any fresh-candidate claim.
2. Aggregate the T2 candidate-bound refs, axes, package, E0, G-I1A, E1/E2 and UP2 identity receipts without rebuilding or duplicating their implementation.
3. Freeze the candidate-bound lineage before UP2-00 total and formal UP1-04B inputs; stale or foreign receipt reuse is fail_closed.

退出门：

- Proposal/review_pending only; accepted=false and no UP1-04 or UP2-01 execution credit.
- The aggregate gate is independently reviewable after T2; old UP1-04A/G-I1A/N05/N06/UP2 local receipts remain historical only.

时序约束：三张 upstream 声明先冻结，再创建新候选并重建 refs/hash/axes/package/E0/G-I1A/E1/E2/UP2 identities；随后才冻结并执行该新候选的 UP2-00 total、UP1-04B B00 F0–F5、50 条 B04 fresh receipts、checker 和 two-process replay；完成 UP1-04 后才释放 UP2-01。任何 upstream Genome 变化都必须重新冻结候选并重建正式 50/B00 证据。

<a id="up1-04a-vnext-t0"></a>

### UP1-04A-VNEXT-T0 additive V1 declaration transport

当前状态：`planned`，`scope_status=proposal`，`accepted=false`，`resolution=review_pending`；AD-30 仅以 `accepted_limited` 接受架构和排期边界，T0 尚未实施。

- 前置：UP1-04A、UP2-01-G1-DIFFUSION-V1、UP2-01-G2-METRIC-BOUNDARY-V1、UP2-01-G3-SOURCE-FEEDBACK-V1。派单时冻结实际 G1/G2/G3 declarations、source/factory receipts、版本、raw/canonical hashes 与 dirty closure；AD-30 中的固定 hash 仅作历史定位，不作为当前输入。本地智能体来源记录即可，不要求外部签发。
- 文件归属：未来仅允许新增 `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl`、对应 `test/GenomeV5/Integration/` T0 测试和 `docs/implementation/UP1-04A-VNEXT-T0/` 记录；不修改旧 V5 Genome、`CandidateStatePackageV5`、shared entry、`default_operator_registry()`、旧 receipt/hash 或其他层文件。本工单登记不等于现在实施源码。

步骤：

1. 定义 additive typed transport envelope，原样保留三张 declaration 的完整 semantic body、source/content/declaration identity，并绑定同一个 fresh candidate。
2. 为 G2 的 GenomeContractRef source field 提供显式 candidate QualifiedRefV1 envelope；四轴使用智能体维护的实际版本、字节与来源记录并逐项核验，不用默认值或标签相似性补轴，不要求外部签发。
3. G3 realization/control/binding children 按实际材料记录 present 或 typed_absent/terminal_deferred，完整保留 feedback target 状态；source rebinding、声明编辑或冲突重算受影响 hashes/identity 或 fail_closed，不能仅因缺外部签名强制 absent。

退出门：

- R2 reviewer 三条件均有 source-backed negative controls：G2 candidate envelope、四轴真实来源/失效、G3 complete declaration-body hash 语义。
- canonical bundle hash 覆盖完整 semantic bodies、source/declaration identity、candidate binding、四轴及 G3 child/feedback state；同候选 exact join 可独立复算。
- 不进入旧 package，不产生 provider/mesh/physical/B00/B04/R01–R10 信用，并取得不同 Luna 独立复核后才可进入 T1。

<a id="up1-04a-vnext-g3-binding-edit-prec"></a>

### UP1-04A-VNEXT-G3-BINDING-EDIT-PREC G3 binding editable sibling precursor

当前状态：`planned`，`scope_status=proposal`，`accepted=false`，`resolution=review_pending`；AD-34 已以 `accepted_limited` 接受架构与工作单边界，当前仅允许 typed-absent scaffold。

- 前置：仅 `UP2-01-G3-SOURCE-FEEDBACK-V1`；与 AD-31、AD-32 及 T0 并行准备，不依赖其实现收据。实际 `PresentChildBindingV1` 还必须等待 checked-present authority recheck 与 same-candidate realization/control source children。
- `write_scope.product_contract_deliverables`（`exact_file_count=6`）：`src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`；`test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl`；`test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json`；`test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py`；`docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md`；`docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json`。不创建 feedback child，不写 T0 authority adapter。
- `write_scope.mandatory_evidence_sidecars`：只允许追加到 `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/archive/**` 或其命名 `review/**`/`status_sync_*/**` 子目录；raw stdout/stderr、exit、PID/UTC、interpreter、input/output hashes、repair/cleanup/review/status receipts 必须保留，不计入 6 个产品/合同 deliverables，不得覆盖旧轮、越出专属目录或由 cleanup 删除。测试使用 direct command，禁止临时 launcher。
- 合同：immutable source payload 显式拥有 `initial_links::Tuple{Vararg{G3BindingLinkV1}}`；editable body 初始 canonical bytes 必须精确复制；`source_content_hash`、`binding_child_identity_hash`、`initial_body_hash`、`initial_source_state_hash` 与 typed operation history 分层且独立重算。child slots 仅为 `PresentChildBindingV1 | AbsentChildBindingV1`。
- 现状上限：独立 T0 authority recheck 未输出 checked-present 前只能建立 `AbsentChildBindingV1`，原因/absence digest 不得伪造 child/ref/hash。`insert_link`、`replace_link`、`delete_link` CAS 全部禁用，返回 `authority_recheck_not_published` 或 `binding_authority_typed_absent`，失败保持旧 canonical bytes、history 和 hashes 不变。
- legacy pairing：G1/G2 upstream authority 各恰好一个；duplicate/missing/unknown layer、target layer/candidate/authority mismatch、duplicate/ambiguous target 均 `fail_closed`。legacy six-field equality 只查内部一致性，不能晋升；legacy `:actual` 仍为 typed-absent/`terminal_deferred`。
- 退出门：未来实现需有 source/body/state/operation round-trip、typed absence、recheck-present/absent、CAS stale/duplicate/foreign 与 fail-atomic 负控，并由不同 Luna 复核；最高 `accepted_limited` contract-only，不授 actual binding/feedback/control/T0/T1/T2/provider/mesh/engineering/physical/search/B00/B04/R01–R10 信用。

<a id="up1-04a-vnext-t0-authority-recheck-prec"></a>

### UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC 本地来源与声明一致性复核

待验收状态保持 planned/accepted=false，直到版本化本地路径有实际实现和复核；成功输出为 local_checked_present，明确属于项目内数据一致性，不冒称外部认证。旧 accepted_limited 仅描述历史 scaffold。

- 前置：`UP1-04A-VNEXT-T0`；这是 T0 输出后的 authority recheck gate，必须在 T1 前完成。未来 T1 同时依赖 T0 与本 recheck，保持无环；T0 本身不改。
- 写入范围：派单时冻结本地适配器、对应测试和新档案的确切文件；旧七文件列表仅作历史定位，不再禁止必需的版本化适配。不得覆写旧验收书、重解释旧 hash 或放宽外部验证 API。
- 证据归档：在本任务目录追加新轮次的实际输入/输出、直接命令、日志、退出码和复核；不覆盖旧记录，不再冻结产品文件数为七。
- 输入/输出：输入为实际 T0 bundle、智能体生成的本地 declaration/source records 及 canonical bytes；验证 layer、candidate、declaration ref/hash、source receipt、bytes 与 bundle 的实际绑定，输出 local_checked_present、typed_absent 或 deterministic fail_closed。不得从 legacy 六字段投影补造缺失内容。
- pairing gate：G1/G2 各 exactly one upstream record；duplicate/missing/unknown layer、target key duplicate/ambiguous、target layer/candidate mismatch 与 source/declaration/feedback 对应矛盾必须失败。本地完整一致的记录可以通过；投影相等或智能体声明本身不能代替实际材料检查。
- 实现目标：增加版本化本地 recheck 路径，验证实际内容后允许 local_checked_present，不以 trusted_receipt 标签、CA 或外部证明人为前置。旧 AD-34 scaffold 和 R1-R7 记录保留历史语义；不得只把符号改成 trusted 或将旧缺失收据升级为 present。
- 退出门：不同智能体重算 T0 bundle、完整本地来源绑定、canonical equality 及全部 pairing/篡改/缺失负例，通过后可验收本地 recheck 并推进 T1；该结论不自动授予 solver、工程、物理、search、B00/B04 或 R01–R10 验收。

<a id="up1-04a-vnext-parent-baseline-bind-prec"></a>

### UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC 本地 parent-baseline binding

当前机器状态仍为 `planned`、`scope_status=proposal`、`accepted=false`、
`resolution=review_pending`。本地 bounded software slice 已由独立
`independent_agent_local_r8_postrun` 复核为 `accepted_local_contract`：focused
contract `82/82`、static QA `133/133`；claim ceiling 仍为
`contract_only`。这只同步本地软件边界，actual source-backed parent present
authority 仍为 `pending_this_node_verification`，不代表 T0/T1/T2 或 formal
acceptance。

- 前置：UP1-01、UP1-02、UP1-03；本任务不单独接受 T0/T1/T2。
- 文件归属：Integration 中的 baseline binding 或版本化本地适配、对应测试及本任务目录的新一轮证据；派单时冻结确切路径，不覆盖 AD-33 旧档案。

步骤：

1. 输入：accepted UP1-01/02/03 合同与只读 G1/G2 V1 declaration source；输出为 `PresentParentBaselineBindingV1 | AbsentParentBaselineBindingV1`、对应 present/absent child key union 及 typed-absent state contract。
2. 实现目标：依据真实本地 G1/G2 declaration bytes、source locator、factory receipt 和同候选绑定构建 present；必要输入缺失时才返回 typed_absent/terminal_deferred，不预设永久 absent 上限，不需要外部签发。Absent branch 不用零值伪造 parent ref/hash 或 receipt。
3. 编辑边界：absent state 禁止 replace_source_payload；失败不推进 state/history，prior canonical bytes 与 SHA 不变。材料补齐后生成 fresh local source record、child/state/candidate identity，由不同智能体重算复核；不改写旧 absent 收据，不要求外部 source publication。

退出门：

- Present 条件：G1/G2 各自实际 source-backed V1 instance/factory/declaration receipt、完整哈希与 fresh same-candidate identity 复核；智能体可创建和验证这些本地材料。该节点不单独代表 T0/T1、数值或物理验收。
- 历史 AD-33 只接受 typed-absent 软件切片，不能证明新的 present 实现。新 present 路径通过内容绑定、编辑原子性和缺失/篡改负例及智能体复核后可按软件范围接受，不自动验收 T0/T1/T2、UP2、solver、工程、物理、search、B00/B04 或 R01–R10。

历史依据：[AD-33 acceptance](../implementation/AD-33/acceptance.md)、[status sync R2](../implementation/AD-33/status_sync_r2/report.md)。当前 bounded 状态同步见 [status_sync_local_r1](../implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/status_sync_local_r1/report.md)，实际 source-backed present authority 仍待本节点正式验证。直接测试入口为 `julia --project=. test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl`；新增适配器需补对应直接测试，旧测试通过不代替新 present 路径验证。

<a id="up1-04a-vnext-g3-realization-edit-prec"></a>

### UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC realization source-edit precursor

Current status: `planned`, `scope_status=proposal`, `accepted=false`, `resolution=review_pending`; AD-31 is accepted_limited for architecture/work-order scope, and the local source/test slice is separately `accepted_limited` on frozen focused_r4 software evidence. This is a parallel contract-only precursor and is not a T0/T1/T2 main-DAG completion or substitute.

- Prerequisite: `UP2-01-G3-SOURCE-FEEDBACK-V1` accepted architecture/declaration plus AD-31 acceptance. It does not import or depend on T0; future T1 source-backed lossless mapping is a separate gate.
- File ownership: only new `src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl`, new `test/GenomeV5/G3/g3_realization_child_editability_v1_tests.jl`, and `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/`; old G3 V5/package/registry, T0, core planning files and receipts remain read-only.
- Inputs: current G3 SourceFeedback V1 declaration contract, read-only old realization field definitions for comparison, AD-31 closed source/edit/hash contract, and fresh typed local values; no historical candidate evidence.
- Outputs: one closed typed realization source body/state, typed parent G3 declaration ref/hash, additive child contract identity, closed four-slot provenance or typed absence, fixed `replace_source_payload`, five-hash recipe and software-only evidence archive.
- Frozen-r4 local software record: PID `15468`, UTC `2026-09-15T02:20:48.9783709Z`–`2026-09-15T02:20:59.4391247Z`, exit `0`, 65/65 assertions; stdout 130 bytes SHA256 `3cb363b0e53ff26ca9a632a9838c394d95a97e65a6cad453c750a0dcc6803d3f`, stderr 0 bytes SHA256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; 13 frozen inputs, 306 dirty rows before/after, empty Julia/DESC process snapshots. See [local software precursor acceptance](../implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/software_precursor_acceptance.md) and [status sync R1](../implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/status_sync_r1/report.md).
- This local acceptance is frozen-r4 only. Concurrent drift in planning inputs observed after the run is not back-attributed to the R6 source/test slice; the frozen input manifest controls receipt reuse. The machine node remains `accepted=false`, and actual child, T0/T1/T2, provider, mesh, engineering, physical, search, B00, B04 and R01–R10 remain false.

Steps:

1. Define a closed candidate-owned realization source body preserving typed resource ports, components, material/manufacturing domains, ledger accounts/entries/closures and local invariants; reject open dictionaries, dynamic fields and old-type aliases.
2. Define the child key and typed parent/child contract identities; compute independent source-record, source-content, initial-state, operation and state hashes; implement only atomic `replace_source_payload` with separate stale source/state `fail_closed` paths.
3. Keep missing provenance/authority as typed absence/`terminal_deferred` and keep `contract_admission` separate from `physical_resolution`; do not import/redefine T0 authority or implement control/binding/feedback children.

Exit gates:

- closed body, parent/child identity, closed provenance, non-recursive five-hash recomputation and fixed operation pass source-backed negative controls;
- missing provenance is typed absent/`terminal_deferred`; foreign/stale/forged identity or hash, malformed body and forbidden generic edits are `fail_closed` with the prior state unchanged;
- a different Luna reviews source, raw focused receipt bytes, dirty-work protection and dual status ceiling; acceptance is software contract-only and does not grant actual child, T0/T1, provider, mesh, engineering, physical, search, B00/B04 or R01–R10 credit.

Control, binding and feedback editability are excluded from this precursor and require separate finite work orders. Completion of this node must not mark T0, T1, T2 or the `UP1-04A-VNEXT` aggregate gate complete.

<a id="up1-04a-vnext-g3-control-edit-prec"></a>

### UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC control source-edit precursor

Current status: `planned`, `scope_status=proposal`, `accepted=false`, `resolution=review_pending`; AD-32 is `accepted_limited` for architecture/work-order scope, and the local source/test software slice is separately `accepted_limited` on frozen R9 evidence after independent postrun R3 `pass_limited`. This is a control-only sibling of the realization precursor, parallel to T0, and not a T0/T1/T2 completion or substitute.

- Prerequisite: `UP2-01-G3-SOURCE-FEEDBACK-V1` and AD-32. It does not import or depend on realization or T0; a future T1 mapping is a separate source-backed gate.
- File ownership: only new `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`, new `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`, and `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/`. Old `ControlGenomeV5`, package/registry, T0, core planning files and receipts remain read-only.
- Inputs: current G3 SourceFeedback V1 declaration, AD-32/R7 closed control contract, read-only old ControlGenomeV5 semantics, and fresh typed local values; no historical candidate evidence.
- Outputs: one closed typed control body/state, exact derived candidate/parent/child/source refs, four-axis typed provenance or absence, independent source/content/initial/operation/current hash layers, and a software-only receipt for the fixed historical `replace_fault_source_payload` operation.
- Frozen local software acceptance: R9 PID `51564`, UTC `2026-09-15T03:32:47.1548572Z`–`2026-09-15T03:33:03.4679458Z`, exit `0`, `167/167`; stdout 138 bytes SHA256 `6c21dbb806fc5c200ea2f11d31c2b342e8fb6ac0c40d1336c50513bcb354455f`, stderr 0 bytes SHA256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; dirty rows `310/310`, empty Julia/DESC process snapshots; source SHA256 `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb`, test SHA256 `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289`. R8's `149 pass / 18 fail` snapshot-consumption helper bug remains historical evidence. See [software precursor acceptance](../implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/software_precursor_acceptance.md) and [status sync R2](../implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/status_sync_r2/report.md).

Steps:

1. Freeze the field order, type/status domains, source record/ref derivation, parent binding, actual child contract identity, grouped child key and canonical UTF-8/LF bytes; reject forged or foreign refs and hashes.
2. Keep source payload/record/axes/identities immutable and separate from editable state. Permit exactly one existing `fault.mode` change under the historical operation name; reject dynamic paths, insert/delete/rebind, non-mode and multi-fault edits.
3. Implement a closed typed operation-history tuple with globally unique IDs, previous-state chaining, latest-operation invariant, typed absent slots, independent contract/physical status, and all failure paths returning the prior canonical state bytes unchanged.
4. Record focused JSON/canonical/hash evidence and obtain a different Luna review of the implementation. The local source/test slice may be accepted_limited after that review; do not claim physical or engineering control timing.

Exit gates:

- positive construction plus first/second operation transitions; exact identity/ref/source-record consistency; initial/previous/last/current hash chain;
- absence, forged-ref, stale-hash, duplicate/order, non-mode/multi-fault, dynamic-edit and byte-stability negatives; old ControlGenomeV5/package/registry unchanged;
- different-Luna review; local source/test software acceptance is `accepted_limited`, while the machine node remains `planned`/`proposal`/`accepted=false`/`review_pending`; this cannot close T1 or grant actual control, realization/binding/feedback/T0/provider/mesh/engineering/physical/search/B00/B04/R01–R10 credit.

<a id="up1-04a-vnext-t1"></a>

### UP1-04A-VNEXT-T1 CandidateStatePackageV5Next 与 integrator

当前状态：`planned`，`scope_status=proposal`，`accepted=false`，`resolution=review_pending`；只允许在 T0 退出门通过后设计/实施新版本化 package。

- 前置：`UP1-04A-VNEXT-T0`、`UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC`。
- 文件归属：未来新增 `src/Contracts/CandidateStatePackageV5Next.jl`、`src/GenomeV5/Integration/VNextGenomeV5Integration.jl`、对应 `test/GenomeV5/Integration/` T1 测试和 `docs/implementation/UP1-04A-VNEXT-T1/` 记录；不得编辑旧 package、旧 integrator、shared entry、registry 或旧 receipts。

步骤：

1. 构造 AD-19 additive successor，完整承载三张 V1 declaration、source/declaration/bundle identity、candidate binding、四轴和 G3 child/feedback actual-or-typed-absent state。
2. 定义 package hash，覆盖上述完整输入及自身 schema/canonicalization/profile hashes；实现 fresh no-legacy pending/typed-deferred receipt 与有 legacy 时完整 before/after provenance。
3. 保持旧 V5/package/hash/receipt/candidate identity 只读；当前所需本地来源、child 或 axis 的实际内容缺失时独立 deferred，结构冲突 fail_closed。外部认证未提供不导致本地 package 缺失。

退出门：

- 新 package/integrator 的 identity 与 hash 可从 T0 bundle 独立 round-trip；旧 package/hash/receipt 未被复用或放宽。
- T1 通过实际 package/integrator round-trip、负例与不同智能体复核后可按本地软件范围 accepted；本次修改不代替验收，不自动产生 B00/B04、provider、mesh、工程、物理或 R01–R10 结论。

<a id="up1-04a-vnext-t2"></a>

### UP1-04A-VNEXT-T2 downstream identity and receipt rebinding

当前状态：`planned`，`scope_status=proposal`，`accepted=false`，`resolution=review_pending`；T2 不与 T0/T1 共享文件所有权。

- 前置：`UP1-04A-VNEXT-T1`。
- 文件归属：未来新增独立版本化 identity/receipt implementation、对应 `test/GenomeV5/Integration/` T2 测试和 `docs/implementation/UP1-04A-VNEXT-T2/` 记录；具体新文件由 T2 freeze 记录，禁止编辑 T0/T1 文件及旧 E0/G-I1A/E1/E2/UP2 receipts。

步骤：

1. 在 T1 新 package 上重建 E0、G-I1A、E1、E2、UP2 source/identity receipts，逐份绑定同一个 fresh candidate、canonical source/bundle identity、三层 hashes、四轴、G3 child/feedback state 和 authority provenance。
2. 对 absent/deferred authority 保持独立 typed `terminal_deferred`；对 stale/foreign ref、hash、axis、child 或 candidate conflict 保持 `fail_closed`。
3. 通过独立审查后，才允许按既有 DAG 继续 UP2-00 total、UP1-04B formal B00 F0–F5、50 条 B04 fresh receipts、checker 和 two-process replay 的后续冻结；T2 本身不执行这些门。

退出门：

- 每份新 identity/receipt 可独立重算，旧 identity/evidence 不迁移、不覆盖；T0/T1/T2 全链仍为 `accepted=false` 直到各自实现和独立审查完成。
- 完成 T2 不自动授予 UP2、B00/B04、provider、mesh、工程、物理、search 或 R01–R10 信用。

<a id="up2-00"></a>

### UP2-00 contract-only typed precompiler schema/validator

当前总门：`review_pending`；AD-28 已 `accepted_limited`，仅为架构/无环排期/证据边界；UP2-00 新候选机器节点仍为 `planned`，依赖 T2 后的 `UP1-04A-VNEXT` 综合冻结/独立验收汇聚，不重复实施 T0/T1/T2。独立 r18 已以 `accepted_limited` 接受实际 A package 的 N01/N02 schema/value projection 局部范围；N07/N08 与 N09 另有局部 `accepted_limited` 合同归档，但不计入正式 B04 receipts；UP2-00 总门仍未接受，历史 40/50 local mutation slots 尚未完成，且全部 50 条正式 B04 receipts 仍 pending，等待后续 contract-only typed precompiler schema/validator 完成。归档：[UP2-00 acceptance](../implementation/UP2-00/acceptance.md)、[独立 r18 复核](../implementation/UP2-00/independent_review_r18/acceptance.md)、[AD-28 acceptance](../implementation/AD-28/status_sync_r3/acceptance.md)。

- 前置：UP1-04A-VNEXT；旧 UP1-04A limited receipts 不替代 T0/T1/T2 和新候选重绑定。
- 技术章：[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)；冻结义务：[19_up0_02_contract_freeze.md](19_up0_02_contract_freeze.md)。
- 输入：T2 后 `UP1-04A-VNEXT` 综合冻结的 candidate-bound package/identity receipts、B04 N01–N10 真实 typed precompiler 字段和预注册错误分类。
- 写入范围：typed schema、validator、正式 fixture/checker 与 invocation-count interface；不写 solver、mesh、provider 或物理后端。

执行步骤：

1. 把 B04 N01–N10 绑定到实际 typed precompiler 字段与预注册错误分类。
2. 提供 compile-before-provider and provider invocation count interfaces；结构 invalid 必须 fail_closed，provider gap 单独保留。
3. 在 UP1-04B 执行前冻结 schema-bound formal inputs/version/hash recipe；不执行 solver、mesh、provider 或 physical run。

退出门：

r18 independent review accepts only the actual-A N01/N02 schema/value projection slice with source-derived error code/path, changed input hash, and zero invocation counters；it does not accept total UP2-00。
- UP2-00 total gate remains open：N03、N04、N05、N06–N10 and 40 pending mutations still require real source fields/classifications before UP1-04B。
- Current-status clarification (2026-09-14): N03/N04/N07/N08/N09/N10 now have separately recorded local accepted_limited slices; the 40/50 and all 50 formal B04 receipts remain historical/total-gate obligations, and local slices do not count toward the 50 fresh formal receipts, checker, or two-process replay.
- Current-status clarification: N03/N04/N07/N08/N09/N10 now have separately recorded local accepted_limited slices; the 40/50 and all 50 formal B04 receipts remain historical/total-gate obligations, and local slices do not count toward the 50 fresh formal receipts, checker, or two-process replay.
- Local N07/N08/N09 accepted_limited projections remain separate contract evidence; they do not count toward the 50 fresh formal B04 receipts, checker, or two-process replay.
- UP2-00 is contract-only and grants no solver/mesh/provider/physical or B00/B04 execution credit。

AD-21 补充边界：当前 UP2 typed-wrapper mutations 仅为 `schema_validation_only`；只有实际 `CandidateStatePackageV5` 的 A factory projection 是 source-backed。低层 `UP2PrecompilerInputV1(...)` 可构造 synthetic/unverified input，不是 B04-admissible input。UP2 partial acceptance 必须由独立 Luna 复核，并对 actual A package 的每条已实现 mutation 留下 source-derived `error_code`、`error_path`、mutated value/hash 和 compile/provider/solver counters；`expected_error` 只能作为断言，不能驱动分类或路由。UP2 total 仍须 N01–N10 共 50 条真实 source fields/classifications。

AD-21 independent limited-review archive：[implementation acceptance](../implementation/AD-21/acceptance.md)、[independent review](../implementation/AD-21/independent_review/report.md)。

UP1-04B 首次执行前冻结 candidate-bound mutation envelope，至少包含 baseline `CandidateStatePackageV5` hash、精确 G1/G2/G3 或 precompiler source ref/hash/path/type、原始与 mutated typed values、mutation id、schema/canonicalization hashes，以及由 source/invariants 推导的 classification。构造器提前拒绝非法值时，receipt 仍须绑定真实 baseline 和 attempted value。缺 authoritative port/unit/time/account/source/receipt join 继续独立 deferred；禁止复制 expected_error、synthetic low-level input、旧 evidence 或 label routing。50 条新鲜 receipts、checker 与双独立进程 replay 完成前，B00/B04、工程、物理和 R01–R10 仍为 false。

<a id="up1-04b"></a>

### UP1-04B B00/B04 正式冻结、checker 与双进程复放

当前状态：`planned`，等待 UP2-00 contract-only schema/validator。

- 前置：UP2-00。
- 技术章：[13_acceptance_benchmarks_and_evidence.md](13_acceptance_benchmarks_and_evidence.md)；冻结义务：[19_up0_02_contract_freeze.md](19_up0_02_contract_freeze.md)。
- 输入：最终 schema、UP2-00 validator、UP1-04A-VNEXT 三层新 candidate refs、B00 F0–F5 和 B04 N01–N10 mutation receipt 规范。
- 写入范围：正式 fixture、checker、two-process replay recipe、ledger 和专属归档；重计算按串行 lane 执行。

执行步骤：

1. 在最终 schema 后、首次执行前冻结 B00 F0–F5 与 B04 50 formal mutations/receipts/checker version and input hashes。
2. 串行执行 fresh candidate-bound suite with checker and two-process replay；保留 stdout/stderr/exit 与 ledger。
3. 由不同 Luna 独立复核 formal mutation coverage、receipt identity 和 checker provenance。

退出门：

- All B00 F0–F5 and 50 B04 mutations must have fresh candidate-bound receipts, checker evidence, and two-process replay before UP1-04 can be accepted。
- UP1-04B cannot be accepted from runner exit alone；provider、mesh、engineering、physical 和 R01–R10 credit remain separately gated。

<a id="up1-04"></a>

### UP1-04 Genome 迁移与入口集成

当前状态：`planned`（总门依赖 UP1-04B；UP1-04A 已 limited accepted，UP2-00 total 为 `planned`/`review_pending` 且 `accepted=false`，只有 scoped `accepted_limited` local slices；UP1-04B 尚未完成）。UP1-INDEX 归档：[UP1-INDEX acceptance](../implementation/UP1-INDEX/acceptance.md)。

- 前置：UP1-04B；UP1-01/02/03 由 UP1-04A 汇入。
- 技术章：[10_genome_upgrade_execution.md](10_genome_upgrade_execution.md)；验收基准：B00、B04、B11，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 汇入 UP1-04A-VNEXT 的新候选共享入口/身份重绑定与 UP2-00 的 contract-only schema/validator 输出。
- 只在 UP1-04B 的 B00/B04 receipts、checker 与 two-process replay 完成且独立复核后接受完整 migration/package join。
- 保留 provider、mesh、工程、物理和 R01–R10 的独立证据边界。

- 输入：三条 Genome 交付、冻结 schema 版本及迁移协议。
- 写入范围：集成者独占 Genomes 注册/包入口/相关测试清单；不得改 unrelated dirty 文件。

版本与迁移前置门（见 [AD-17](18_sources_and_architecture_decisions.md#ad-17)）：`GenomeContractRef.version` 按合同修订 token 比较，类型名另列；G1/G2/G3 对外 ref 与 G3 realization/control 外部 bundle 使用 `v5`，G1 payload schema 独立使用 `v2`，G3 `CoupledRealizationControlBindingV2` 及其 schema 使用 `v2`。三层对外各自必须是公共 `GenomeContractRef`，不得用自定义 alias、nullable hash、标签 digest 或字符串相似替代；真实 schema/canonical hash 不存在时只能显式 `deferred`。

AD-18 G3 feedback authority gate（见 [AD-18](18_sources_and_architecture_decisions.md#ad-18)）：G3 standalone 只能核对 `feedback.target_contract_ref` 的目标层 namespace、`v5` token 和基本公共 ref 形状；错误层、错误 version、缺字段或错误形状立即 fail-closed。fixture seed 或合成 `/feedback-target` ref 只能用于结构负控，不能满足 authority。

- 在 standalone admission 中，若同一 candidate 的实际 G1/G2 外层公共 refs 未随输入提供，必须产生独立 `feedback_authority_gap`，resolution=`terminal_deferred`；provider gap 单独保留，不能转写或互相覆盖。
- 完整 UP1-04 只能在 B 阶段完成并经不同 Luna 独立复核后接受；UP1-04A 的共享入口结果不能替代总门。
- 新 candidate 的三层公共 refs、四轴、candidate binding 和 identity exact-bound；历史 UP1-02 urn:fusion:g2:* ref/hash/evidence 不复用。
- UP1-04 收到真实三层 bundle 后，必须逐字段 exact compare 目标 URI、version、schema、canonical、profile、四轴和 candidate binding，并重建 candidate identity；任一层/版本/ref/轴/binding 不匹配必须 fail-closed。
- 该门只规定合同 authority 的可消费边界；它不提供 provider、B00/B04、mesh、工程、物理或 R01–R10 信用。


执行步骤：

1. 实现旧配置兼容与显式 migration receipt，创建新候选 fixture 并重建受影响身份。
2. 将新组件接入现有包及测试路径，避免只在 standalone 文件可执行。
3. 运行标签擦除、节点/区域置换、迁移往返/拒绝及相邻回归。
4. 对每一个旧占位 ref 生成 before/after 完整 ref 记录，包含 schema/canonical/profile hash、四轴版本域和 candidate identity 重建；含糊映射必须拒绝。
5. 在 schema 完成后、首次执行前另冻正式 B00/B04 fixture 与 suite 版本；不能把 19/protocol 的 illustrative pending fixture 当执行证据。

退出门：

- 新旧证据不混用；版本缺失或含糊不能猜测。
- 新三层 bundle 可从现有项目入口读取，旧可接受配置不被无意破坏。
- 每层公共 `GenomeContractRef` 的实际 schema/canonical hash、profile hash、四轴、G3 child refs/binding 与 candidate identity 精确一致；缺少真实 provider/schema 时保留独立 `deferred`，不得伪造通过。
- migration receipt 覆盖每个旧占位 ref 的完整 before/after 与身份重建，标签擦除、节点/区域置换和往返/拒绝均通过；旧 evidence/hash 不复用。
- 正式 B00/B04 suite 已在首次执行前冻结并由新鲜 candidate-bound receipt 证明；没有该证据不得接受集成。UP1-02 的有限 G2 structural acceptance 不替代此门，当前 G1/G3 代码也不因本单视为通过。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up2-01"></a>

### UP2-01 声明驱动的物理方程编译

- 前置：完整 UP1-04 总门完成（其内部依赖 UP1-04B）；UP1-04 父工单在 B 之后统一关账。
- 技术章：[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)；验收基准：B01、B04，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：typed bundle、算子/closure 注册、已有 Compiler/FieldProgramEvaluation/FieldResidualPipeline。
- 写入范围：编译器、专属 equation/lowering 模块和测试；共享入口由集成任务修改。

执行步骤：

1. 将状态/参数/端口与 region 绑定为 equation IR，输出所有闭合和边界义务。
2. 逐算子组合 lowering，支持变系数与各向异性扩散、时间项和多场项；保留固定公式为回归 fixture。
3. 生成结构稀疏关系及 AD/解析/数值导数的适用性元数据；拒绝未经声明的替代闭合。

退出门：

- 未知合法组合能编成真实残差；不检查整棵 AST 是否等于 fixture。
- 缺算子执行器、闭合或边界明确延期；无 name/family/ID 路由。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up2-02"></a>

### UP2-02 空间物化、离散组装与一般入口

- 前置：UP2-01。
- 技术章：[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)；验收基准：B01、B02、B04，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：equation IR、G2 域/场空间、离散 profile、边界和材料数据。
- 写入范围：空间 mesh/assembly 模块及专属测试；拟建通用 candidate-input 入口接口。

执行步骤：

1. 实现经过验证的几何→网格/基空间→弱式或数值通量装配。
2. 以完整能力合法性检查取代 _smr_declaration 的固定模型身份守卫；守卫替换须与真实执行支持同批落地。
3. 支持不靠修改源码的候选数据输入；旧固定示例走该入口的兼容适配。

退出门：

- 变系数/边界/区域连接变化无需改代码；至少一项留出声明执行。
- MMS 的解误差、残差、积分守恒、网格/时间细化各自通过冻结门。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up2-03"></a>

### UP2-03 拓扑传递与外部区域闭合

- 前置：UP2-02。
- 技术章：[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)；验收基准：B02、B05、B06，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：网格/场空间、G1 守恒账户、接口条件、外域/源/回流声明。
- 写入范围：传递、接口和外域模块及专属测试。

执行步骤：

1. 实现重网格/分裂合并后的守恒投影，约束 divB、正性和规范条件，无法同时满足时返回诊断。
2. 实现一条明确适用的外域路径，如真空/导体域加远场截断；源/电路回流由 G3 明确给出。
3. 对静态设计拓扑编辑和物理拓扑事件分别验证，禁止把数值重映射当磁重联物理。

退出门：

- 转移前后总量差在冻结容差内；场约束与局部误差通过。
- 远场截断/外域网格细化敏感性通过；删外域或漏回流负控不得获信用。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up2-04"></a>

### UP2-04 耦合求解、约束与集成

- 前置：UP2-03。
- 技术章：[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)；验收基准：B01、B02、B08、B11，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：离散残差/稀疏结构、端口依赖、初值与约束、现有求解器停滞诊断。
- 写入范围：耦合求解器及集成者独占的公共入口/测试清单/运行器。

执行步骤：

1. 依据依赖图识别强耦合块/DAE和约束，采用经过验证的 Newton/Krylov/ODE-DAE 等算法。
2. 处理规范零空间、初值一致性、约束方向和全局化；保留真实失败信息，不靠增大迭代数掩盖病态。
3. 集成同一 candidate-bound 入口，串行运行组件和相邻整体回归。

退出门：

- 所有强耦合残差和守恒同时通过；一轮顺序后处理不能算闭环。
- 故意错误 Jacobian、缺初值、停滞与约束失败被正确识别。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up2-05"></a>

### UP2-05 成熟物理模块及 backend 能力登记

- 前置：UP2-04。
- 技术章：[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)；验收基准：B01、B04、B06，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：已运行的组件核、成熟库官方文档/锁定版本、完整 capability schema。
- 写入范围：独立 provider adapters、隔离 manifest、协议测试；不随意扩默认 operator registry。

执行步骤：

1. 先接可验证的扩散/电磁/电路/热/弹性模块，逐项登记输入输出、边界、时间、材料及误差范围。
2. FreeGS/DESC 保留适用域适配器；FUSE 可作为集成参考/后端而非任意拓扑总入口。
3. 为 transport/kinetic/burn/loss 等尚缺模块列出明确模型、接口、数据/资源与 UP6 拆单触发条件。

退出门：

- 每个 claimed module 有组件执行与负例；仅安装包或 bridge_ready 不能记 provider 证据。
- 删除某 provider 后完整路由返回具体缺口，不能降级到隐藏族模板。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up3-01"></a>

### UP3-01 自动组合执行矩阵

- 前置：UP2-05。
- 技术章：[12_composition_and_inverse_realization.md](12_composition_and_inverse_realization.md)；验收基准：B01、B02、B04、B08，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：模块注册、统一编译入口、冻结组合矩阵及各组件 oracle。
- 写入范围：组合 fixtures、独立基准运行器/检查器；不改物理模块以识别候选。

执行步骤：

1. 按12中的递进组合从变系数扩散扩展到电磁-电路-热-结构，组合关系由 typed 端口和方程生成。
2. 冻结构建集与组合留出集；计算耦合解并与解析/独立离散基准比较。
3. 逐一拆掉耦合回传边作负控，确认相关输出真的响应反馈。

退出门：

- 同一入口自动生成联合系统，无专门手写候选驱动或完整方程模板。
- 每个声明支持组合有真实结果与守恒账本；未支持组合明确延期。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up3-02"></a>

### UP3-02 留出组合与通用性反证测试

- 前置：UP3-01。
- 技术章：[13_acceptance_benchmarks_and_evidence.md](13_acceptance_benchmarks_and_evidence.md)；验收基准：B00、B04、B05、B11，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：冻结后隐藏的合法组合、非法配置、label/ordering 变换、组合执行产物。
- 写入范围：独立 reviewer 测试/审计文件，不改被测实现绕过失败。

执行步骤：

1. 评审者生成未在实现分支出现的合法组合；至少变化系数结构、边界或区域连接之一。
2. 做标签擦除/排列不变、量纲错误/边界缺口/不支持导数拒绝以及 provider-dropout。
3. 汇总能力矩阵，区分声明合法、可物化、可求解、数值通过、物理适用。

退出门：

- 通过配置无 candidate-specific 源码补丁；拒绝负例的原因可追溯。
- UP3 acceptance 对准确 capability scope 生效，未覆盖域保持开放。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up3-03"></a>

### UP3-03 可选的受验证基降维

- 前置：UP3-02。可选加速，不阻塞主链。
- 技术章：[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)；验收基准：B01、B02、B03、B06，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：已经收敛的高维系统、训练/验证/留出样本、约束和量纲。
- 写入范围：ROM/POD/投影适配器及独立误差检查器；可选，不是后续必需依赖。

执行步骤：

1. 先分析规范零空间和可识别性，再选择谱基/POD/约束投影，报告离线与在线成本。
2. 加入守恒/约束保留、误差估计、OOD 和拓扑变化失效协议。
3. 与未参与构基的高维解比较；不收敛或新拓扑时回退完整执行。

退出门：

- 精度和守恒达到冻结误差门，速度收益扣除构基成本。
- ROM 不能填补闭合/provider缺口，不能单独授予最终证据。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up4-01"></a>

### UP4-01 源与硬件的逆向 realization

- 前置：UP3-02。
- 技术章：[12_composition_and_inverse_realization.md](12_composition_and_inverse_realization.md)；验收基准：B03、B07、B08，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：G3 有限合法设计域、目标场/源需求及精度、实际 forward model、制造/电源限制。
- 写入范围：源/线圈/执行器逆设计模块、约束优化接口与专属测试。

执行步骤：

1. 定义设计自由度与可制造参数化、目标函数、端口电源和回流约束。
2. 通过受约束多起点优化拟合目标，并报告不可识别方向、局部极小与不可达残差。
3. 将实现源替代目标源生成新输入，重跑主物理；静态场不得产生无时变依据的 EMF。

退出门：

- 至少一项候选绑定逆设计实际执行并形成硬件参数与误差证据。
- 故意不可实现的目标不能被免费源/无限电流等默认值通过。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up4-02"></a>

### UP4-02 热、材料、结构与控制回代

- 前置：UP4-01。
- 技术章：[12_composition_and_inverse_realization.md](12_composition_and_inverse_realization.md)；验收基准：B02、B08、B12，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：实际源/硬件参数、材料数据、供能周期、热沉/冷却/结构边界、控制故障场景。
- 写入范围：工程反馈组合及专属测试；不在独立后处理报告中伪造反馈。

执行步骤：

1. 联合求电路损耗、热传输和结构响应，把温度材料变化/位移重新传入源与场计算。
2. 扩展控制饱和、故障和启停场景，同一硬件设计跨 required scenarios 使用。
3. 逐项核对能量与物质账本，检查长期储能透支和热积累。

退出门：

- 闭环误差、耦合残差、守恒和材料/温度/应力门同时成立。
- 去掉冷却/电源限制/反馈边的负例能触发失败；未验证数据不默认安全。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up4-03"></a>

### UP4-03 真实参考表示与隐参逆恢复

- 前置：UP4-02。
- 技术章：[13_acceptance_benchmarks_and_evidence.md](13_acceptance_benchmarks_and_evidence.md)；验收基准：B03、B06、B07，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：有来源和适用域的参考装置/实验或设计数据；校准与留出协议。
- 写入范围：reference data adapters、inverse benchmark、独立识别/UQ检查器。

执行步骤：

1. 先 round-trip 表示真实参考的已知属性并记录无法表示部分，不把自生成 MMS 称真实参考。
2. 隐藏可识别变量、从多个初值反演，计算灵敏度秩/条件与参数不确定性。
3. 用未参与拟合的场景/观测验证预测，并测试 grammar 可达恢复；ITER 设计Q不等于净电输出。

退出门：

- 真实来源、模型适用性、识别和留出全部有实证；参数回收不靠答案泄漏。
- 非唯一时报告可辨识组合/区间，不宣称精确恢复全部参数。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up4-04"></a>

### UP4-04 逆实现闭环集成验收

- 前置：UP4-03。
- 技术章：[12_composition_and_inverse_realization.md](12_composition_and_inverse_realization.md)；验收基准：B08、B11、B12，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：源逆设计、工程反馈、真实参考逆恢复交付及 UP3 组合证据。
- 写入范围：集成者独占完整路径运行器/测试清单；独立审计包。

执行步骤：

1. 将需求→设计→实际源→主物理→工程回代串入同一版本化执行计划和检查点。
2. 新鲜运行并检查各阶段 candidate/scenario/input/provider 哈希贯通。
3. 审查外域、控制、热和实现误差是否真正回传，记录剩余整装物理义务。

退出门：

- 不是只存在多个独立脚本；同一输入可重建闭环及其失败恢复。
- 有限模块闭环验收不抵消尚缺 transport/burn/稳定性或完整整装义务。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up5-01"></a>

### UP5-01 条件 e-graph 接入

- 前置：UP4-04。
- 技术章：[typed AST、operator hypergraph 或 e-graph.md](<typed AST、operator hypergraph 或 e-graph.md>)；验收基准：B04、B09、B11，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：现有有限整程序 egraph、已验证算子语义与条件规则、运行缓存身份规则。
- 写入范围：egraph adapter/typed rewrites/重放检查器；不更改 evidence authority。

执行步骤：

1. 先连接保守规范化和有限条件等价去重；子表达式 congruence 扩展需逐条规则验证。
2. 条件包含单位、域、边界、时序、效应和闭合；浮点/连续/离散等价作用域分开。
3. 记录 ruleset/order/budget/trace 与 incomplete 状态，禁止未饱和即宣称不等价。

退出门：

- 每条合并可独立重放，条件不成立不合并；表达式改写不自动转移求解证据。
- 同配置确定性重放；有限预算不同顺序不强求同闭包。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up5-02"></a>

### UP5-02 丰富 typed edits 与物理反馈

- 前置：UP5-01。
- 技术章：[03_open_ended_evolution_and_quality_diversity.md](03_open_ended_evolution_and_quality_diversity.md)；验收基准：B05、B08、B09、B10，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：完整能力矩阵、真实求解/工程反馈、旧0D screen emitter、失败与休眠档案。
- 写入范围：typed mutation/crossover、search/archive模块与专属测试。

执行步骤：

1. 实现 G1算子/closure、G2域连接/基阶/几何、G3源网络/材料/控制的合法编辑；每个新物理对象重建身份。
2. 把残差定位、约束敏感度、实现误差、热/供能瓶颈作为编辑/预算反馈；缺provider单列执行工作。
3. 实现可恢复 QD、失败前沿和渐进 MCTS，先有界真实循环，再考虑代理/GFlowNet。

退出门：

- 至少分别有 G1/G2/G3 编辑引起可观察的执行/反馈变化，非只改常数或标签。
- 搜索提议与物理/晋升 authority 隔离，失败不被无证据永久剪枝。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up5-03"></a>

### UP5-03 有界比较 campaign 后扩容

- 前置：UP5-02。
- 技术章：[06_multifidelity_hard_physics_frontier.md](06_multifidelity_hard_physics_frontier.md)；验收基准：B09、B10、B11，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：冻结成对预算/种子/能力范围、baseline与新emitter、执行成本和剪枝审计协议。
- 写入范围：campaign manifests、只增 run 输出、审计/统计和档案更新器。

执行步骤：

1. 执行同预算基线/增强搜索，分别计 proposal、语义结构、可执行输入和硬门通过数。
2. 比较新可达能力域、单位实际计算成本收益与假阴性，审计休眠恢复和严格合并。
3. 若缺provider或数值失败主导，暂停扩容转派相应执行修复；可用结果达门后逐档增预算。

退出门：

- 规模由实际能力收益和资源批准驱动；不把预设50–100cells当无条件先跑要求。
- 真实物理反馈闭环、证据身份、复放均通过，原父目标仍独立记账。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up6-01"></a>

### UP6-01 补齐整装必需物理和工程覆盖

- 前置：UP5-03。
- 技术章：[08_high_fidelity_whole_device_vvuq.md](08_high_fidelity_whole_device_vvuq.md)；验收基准：B01、B02、B06、B08、B12，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：冻结 mission、完整 obligation ledger、各provider适用域、尚缺模型/数据清单。
- 写入范围：按缺口拆成有限子工单的物理/工程适配器；集成入口单独拥有。

执行步骤：

1. 对每个候选枚举平衡、动态稳定性、轨道/损失、输运、燃烧/粒子、辐射及适用动理学义务。
2. 枚举外域、加热/电源、冷却、材料/结构、控制故障、燃料循环、转换和厂用电；每个缺口分配具体模型/数据/provider/测试子单。
3. 逐项实现并验证后重走已有组合与闭环协议，不能跳过无法做的项或以新文档代替。

退出门：

- 所有required模型和工程义务候选绑定执行且满足预注册门；不适用项有证据。
- 若需外部验证资源，具体blocked项保持开放；不得把有限UP4闭环称整装完成。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up6-02"></a>

### UP6-02 独立 VVUQ 与整装净输出

- 前置：UP6-01。
- 技术章：[13_acceptance_benchmarks_and_evidence.md](13_acceptance_benchmarks_and_evidence.md)；验收基准：B06、B08、B11、B12，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：收敛整装解、独立数值/物理验证数据、站级全周期账本、UQ协议。
- 写入范围：独立检查器/验证与UQ适配器/整装账本；不编辑被审候选填缺项。

执行步骤：

1. 区分verification、validation、model discrepancy与参数不确定性；与独立实现/数据比较并传播。
2. 计算周期净输出及预注册保守界，包含储能变化、所有供能和辅助损耗，无漏算或重复计能。
3. 对全部required场景核验，来源不足或区间跨零保持unknown/失败。

退出门：

- 有效独立证据及数值协议实际通过；更换线性求解算法不算独立物理验证。
- 候选净输出在冻结不确定性协议下满足正值门。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

<a id="up6-03"></a>

### UP6-03 原创性、独立复放与父目标关账

- 前置：UP6-02。
- 技术章：[09_evidence_authority_campaign_and_v4_roadmap.md](09_evidence_authority_campaign_and_v4_roadmap.md)；验收基准：B11、B12、B13，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 输入：新候选完整证据、外部文献/先例审查、R01–R10及完整复现包。
- 写入范围：独立原创性/复放报告和最终authority交付；原始evidence只读。

执行步骤：

1. 独立审查机制/结构/行为及外部文献相似性，记录检索日期、范围和局限。
2. 由不同执行者在新鲜环境复放全部关键命令并审查数据/身份/退出码。
3. 逐条R01–R10关账，最终authority判定claim ceiling与候选数；未过则返回明确开放项。

退出门：

- 至少一个新候选同时通过所有适用最终物理、工程、净输出、验证与原创性门。
- 只有此时可关父目标；L4不声称已建造并实测正净输出。

失败处置：保留原始执行/数值/物理结果；定位未过的门并提交最小反例。能力缺口延期，数值不收敛不能判全 grammar 无解；不得修改预注册阈值来接受同一运行。交付与复核按 [14](14_agent_orchestration.md)，通过后归档并更新本单状态。

### 所有工作单的 AD-35 关账门

AD-35 当前状态：`accepted_limited`；`accepted=true`；`accepted_scope=collaboration_contract`。该裁决仅接受协作关账合同，39-task count、DAG、主线/物理/R01–R10 credit 边界保持不变。AD-36 sidecars 仅能承载 evidence metadata/raw/reports/inventory/review/status；不得放入产品/合同 deliverable、source、test、fixture、staticQA 或 launcher 来规避 exact scope，发现即 `scope_violation`/`fail_closed`，任务自有越界副本须清理而违规 evidence 受保护。

每个工作单在交给独立复核前必须完成：实现任务的专属正向/负向测试，或纯架构、审计、文档任务适用的 JSON/link/diff/format/static 验证；命令、cwd、PID 或明确 `in_process`、UTC start/end、stdout/stderr/combined raw 内容及 SHA256、exit code、输入/输出/artifact hashes 必须落盘。未有真实实现入口的任务写 `code_tests=not_applicable`，不得把文档检查冒充代码测试。

然后建立逐路径 cleanup inventory 和 `final_exact_owned_set`。只允许删除/回退本任务新建、明确归属本任务且不属于冻结交付、测试、失败 evidence 或 accepted artifact 的 scratch/cache/debug/unrelated code；只要 ownership 不确定就记录 `cleanup_deferred_ambiguous` 并保留。pre-existing dirty、他人文件、R1–R10 失败 raw receipts 和 accepted artifacts 必须保留；禁止 broad glob、全局清理、全局 revert 和隐式递归删除。不同 Luna 复核 cleanup 前后哈希与验证收据，Sol 决定最终状态。该合同见 [AD-35 acceptance](../implementation/AD-35/acceptance.md)；它不新增主线 task、不改变 DAG、不授物理或 R01–R10 信用。

## 首批派发顺序

接手后先派 UP0-01 的只读审计；其完成后由 Sol 裁决基线与开放事项，派 UP0-02 冻结合同。之后三个 Luna 分别接 UP1-01、UP1-02、UP1-03，保持文件互斥；三者交付后轮换一位 Luna 做集成、其他作者交叉复核。不要开场就执行 50–100 个 cell 或启动新 DESC 长跑。

### AD-19 / UP1-04 migration gate

UP1-04 must add an additive, strongly typed CandidateStatePackageV5 migration path. The path consumes the three actual V5 public refs and performs a same-candidate exact join; it does not reinterpret or mutate CandidateStatePackageV4, its Compiler/Campaign call boundaries, or historical evidence. G1 may resolve only after its declaration-driven field, AST, closure, gene, and canonical checks prove the mapping. G2 and G3 mappings remain terminal_deferred until their target semantics and authority are present.

The package exit gate requires exact G1/G2/G3 public refs, candidate URI/ref binding, four version axes, three component hashes, G2 candidate_ref plus real g2_genome_hash, G3 realization/control/binding child refs, and G3 feedback authority against actual same-candidate G1/G2 refs. Structural mismatch is fail_closed; missing mapping, provider, or authority is an independent terminal_deferred gap. A fresh V5 package without legacy input must not fabricate a migration receipt. A legacy receipt must contain complete before/after refs and hashes, axes, field mapping, identity rebuild, algorithm revision, and provenance. B00/B04 suites are frozen only after final schema completion and before first execution. Exit from this work order is contract/integration evidence only; it does not grant provider, B00/B04, engineering, physical, or R01–R10 credit. See [AD-19](18_sources_and_architecture_decisions.md#ad-19).

## 工作单变更和验收记录模板

```json
{
  "task_id": "UP1-01",
  "plan_version": "v4-upgrade-plan-20260914.1",
  "status": "review_pending",
  "base_commit": "<actual>",
  "actual_model": "gpt-5.6-luna",
  "actual_reasoning_effort": "high",
  "contract_hashes": {},
  "protected_file_hashes": {},
  "commands": [{"cwd": "<actual>", "argv": [], "exit_code": null, "log": "<actual>"}],
  "artifacts": [{"path": "<actual>", "sha256": "<actual>"}],
  "implementation_scope": "<exact capability scope>",
  "scientific_status": "<separate from work status>",
  "open_obligations": [],
  "independent_review": {"reviewer": null, "result": "pending", "report": null},
  "sol_decision": "pending"
}
```

这是模板而非有效证据，`<actual>`、null 或 pending 未替换前不能 accepted。未来拆出的子单需要唯一 ID、精确依赖、文件所有权和退出门；原父单仅在所有必需子单通过后接受。

UP2 local accepted_limited slices: N03 covers five actual-A time fields with local G1/G3 checks and retains the candidate-bound G3 time-basis gap as terminal_deferred; N04 covers five actual-A ledger fields, four local invalid-closure mutations, and retains the legal shared-owner and missing exact G1 occurrence-to-G3 account/energy-boundary join gaps. These local slices do not change the UP2-00 review_pending total gate and do not count as any of the 50 fresh formal B04 receipts. N05 is accepted_limited for the local source-bound serialization slice, with the full formal receipt-export gate changes_requested; N06 is accepted_limited only for the actual-A typed projection, five source-derived local mutation classifications, baseline unit/dimension contradiction as fail_closed, and absent cross-layer mapping as terminal_deferred. N10 is accepted_limited for five actual-A identity/receipt fields and same-G2-plan candidate-specific rebinding; UP2 total, all 50 formal B04 receipts, B00/B04, provider, mesh, engineering, physical, and R01-R10 remain unaccepted.

<a id="ad-24-e0"></a>
### AD-24 E0/E1/E2 bounded preparation links

AD-24 is accepted_limited only as an architecture/provenance boundary; it does not change the task_manifest or the UP0-UP6 DAG. The following additive preparation links are bounded work-order guidance and each requires a separate implementation plus different-Luna review gate:

- **E0 — candidate-owned bound-input identity.** Dependency: accepted AD-24 and an actual CandidateStatePackageV5. Output: a new editable binding identity with schema/canonical/profile/binding hashes, unchanged original package hash, and explicit missing authority gaps. Do not create physical evidence or rewrite old package/evidence.
- **E1 — N05 typed declaration.** Status: `accepted_limited` only for actual-A/E0 source-bound serialization positive file-read evidence, including the recorded 323/323 local assertions and seven forged/omitted file-read controls. The full receipt-export gate is `changes_requested`: the seven file-read controls are present, but an independent checker that does not share `_n05e_row` and the formal two-process replay are still missing. Missing authority remains `terminal_deferred`; present conflicts fail_closed. This local status does not accept formal/full B04, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01–R10.
- **E2 — N06 typed mapping.** Dependency: E0. Output: authored source-field-return-heat/ledger/owner-scope mapping bound to actual G1/G2/G3 fields and hashes. Missing cross-layer join remains terminal_deferred.

These links do not accept N05/N06 implementation, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01–R10 credit. Formal B04 receipts and heavy execution remain separately frozen and serially executed under UP1-04B.

UP2-00C-N10 integration status: accepted_limited for the five actual-A identity/receipt fields and same-G2-plan candidate-specific rebinding, with independent r1 pass_limited evidence (80/80 plus 7/7 controls, exit 0, zero compile/provider/solver calls). N10-04 is synthetic attempted-hash only; N10-05 is fresh-receipt-only; V4 legacy provenance remains terminal_deferred. This local archive does not change the UP2-00 total review_pending gate or the requirement for all 50 fresh formal B04 receipts, checker, and two-process replay; B00/B04/provider/mesh/engineering/physical/R01-R10 remain unaccepted.


UP2-00E0 E0 integration status: accepted_limited after independent R3 pass_limited, restricted to actual CandidateStatePackageV5 bound-input source identity and exception-taxonomy software. N05/N06 declarations remain deferred to E1/E2; UP2 total, UP1-04B, all 50 formal B04 receipts/checker/two-process replay, B00/B04, provider, mesh, engineering, physical, and R01-R10 remain pending or unaccepted.

### UP2-00G-I0 additive module seam

Status: `accepted_limited`; scope is limited to additive loader wiring, idempotence, and failure-state software behavior. The accepted focused R3 runtime is exit 0 with 26/26 plus the child failure probe, and the different-Luna postrun review is pass_limited. The entry calls G1/G2/G3 loading first, then registers UP2 definitions in a stable idempotent order with E0 before N05/N06. It does not auto-run a provider, compiler, solver, mesh, or physical stage, and does not alter V4 or the default operator registry.

This is wiring evidence only. UP2-00 still owns the unified contract-only schema/validator; UP1-04B still owns the first formal B00/B04 freeze, 50 fresh receipts, checker, and two-process replay. The dependency route remains `UP2-00 → UP1-04B → UP1-04 → UP2-01`; no local G-I0 result changes the parent R01–R10 scope.

AD-26 is `accepted_limited` for bounded G-I1 architecture/protocol only: E1/E2 authored extensions are additive and context-hashed after actual A+E0, while E0 v1 fields and original identities remain unchanged; `contract_admission` cannot promote `physical_resolution`, and local 50-row classifications cannot replace G-I2/UP1-04B fresh formal receipts. See [AD-26](18_sources_and_architecture_decisions.md#ad-26) and [AD-26 archive](../implementation/AD-26/acceptance.md).

AD-27 is `accepted_limited` for the architecture/evidence boundary only, after independent Luna R1 architecture and R2 provenance `pass_limited` reviews. H0 must be a candidate-owned, versioned, content-hashed typed declaration bound to actual A/E0, four axes, public refs/hashes and exact G1/G2/G3 endpoints; H1 must independently recompute it without H0 expected-row helpers. H0/H1 implementation and a real dimensioned law remain unaccepted. Missing authority remains typed absent/`terminal_deferred`, contradictions `fail_closed`, and unexpected faults `program_exception`. This work order does not turn local N06 unit observations or synthetic laws into physical evidence; UP1-04B still owns B00 F0–F5, 50 fresh B04 receipts, independent checker and two-process replay before any formal acceptance. See [AD-27](18_sources_and_architecture_decisions.md#ad-27) and [AD-27 archive](../implementation/AD-27/decision.md).

UP2-00G-I1A is `accepted_limited` only for the actual-A authority-context software contract: focused_r2 exit 0, GI1A 79/79, E1-present/E2-absent and both-absent source-bound identity, typed E2 synthetic schema/admission, taxonomy/tamper controls and zero downstream counters. A real dimensioned E2 source law, UP2 total, B00/B04, provider, mesh, engineering, physical and R01–R10 remain false; the original R1 failure and repair history stay immutable. See [G-I1A acceptance](../implementation/UP2-00G-I1A-AUTHORITY-CONTEXT/acceptance.md) and [independent postrun r2](../implementation/UP2-00G-I1A-AUTHORITY-CONTEXT/independent_postrun_r2/report.md).


### AD-29 environment reinstallation gate (accepted_limited)

AD-29 is `accepted_limited` only for the environment evidence gate and contract-only planning boundary after independent_review_r1 `pass_limited`. UP1/UP2 contract-only static work may continue. Before `UP2-01` or any provider, mesh, physical, or related combination execution, freeze a fresh candidate-bound environment receipt that binds the current source/input/candidate identity, interpreter and module paths plus SHA256, complete dependency versions and hashes, command/exit/output/artifact hashes, and the applicable capability profile. Record FreeGS's inherited base packages because its venv enables `include-system-site-packages`; record the external source trees for VMEX and Pleiades; record CQL3D as its actual C/Fortran/NetCDF/HDF5 build toolchain, not as a Python environment. The DESC fixed-boundary profile keeps missing `jax-finufft` as an explicit limitation, with NUFFT paths `unsupported`/`terminal_deferred` and no immediate installation requirement.

This is an environment evidence gate, not an execution result. Historical provider/physical receipts cannot be promoted to current reproducibility. `UP2-01` and downstream provider/mesh/physical/combination execution remain `accepted=false`; the 31-task DAG, dependencies and R01–R10 remain unchanged. See [AD-29](18_sources_and_architecture_decisions.md#ad-29), [status sync R2](../implementation/AD-29/status_sync_r2/acceptance.md), and the [status sync R2 evidence](../implementation/AD-29/status_sync_r2/evidence_manifest.json).

# Status synchronization boundary (2026-09-15)

The authorized early preparation for UP3–UP6 may proceed in parallel with the formal dependency chain only within these limits: UP3 may prepare combination/holdout/negative/budget/oracle templates but must not freeze a future candidate hash or run physics; UP4 may prepare reference data, unit/coordinate transforms and source/coil/actuator constraints, with data and adapters archived separately and excluded from the final package; UP5 may audit rewrite rules, applicability and typed edits but must not transfer evidence or prune candidates; UP6 may audit provider/toolchain, VVUQ, engineering obligations, originality, replay and R01–R10 protocols while keeping every conclusion pending. These packages add no machine nodes and do not move formal execution gates. AD-36 sidecars are evidence-only and excluded from exact product counts; AD-37 remains an absence audit/future publication boundary; AD-38 remains a static gap audit blocked on checked-present authority and T1/T2.

# AD-39–AD-42 formal status boundary (2026-09-15)

AD-39 and AD-41 are accepted-limited audit records and do not dispatch or accept publication. AD-40 is accepted-limited for the RepositoryDesignSourceAuthorityV1 architecture and seven finite work-order boundaries. Its W2 products and AD-40 W2 R2 review are retained as point-in-time, typed-absence observations. AD-42 is accepted-limited for the cycle-break audit and W0→W2R1 preparation boundary; W0 may proceed in parallel as prepare-only, but no public ref, declaration or candidate identity may be created from it here.

The local G3 binding precursor is accepted-limited only for its typed-absence software slice. The binding machine node remains `planned`/`proposal`/`accepted=false`/`review_pending`; checked-present authority, actual binding/feedback child, CAS promotion and T1 remain blocked. These status updates do not add AD-39–AD-42 or W0/W2 machine nodes and do not alter the 39-task manifest or DAG. G1/G2 present, T0/T1/T2, UP2, provider, mesh, solver, engineering, physical, search, B00/B04, R01–R10 and L4 remain false/zero.

# AD-42–AD-48 status synchronization (2026-09-15)

AD-42 W2R1 is `accepted_limited` for fresh canonical G1/G2 source authoring only. AD-43 is `accepted_limited` for the general G1/G2 four-axis software contract. AD-44 W3-A is limited to untracked working-tree repository-design source provenance and W3-B remains blocked on a fresh common candidate identity and candidate-bound axis attestations. AD-45 A's common `QualifiedRefV1/v5` is a temporary G1/G2 handle; AD-46 keeps the final identity work orders blocked until exact G1/G2/G3 inputs and independent reviews exist.

AD-47 W0 is an additive G3 axis contract with source-byte/hash closure. AD-47 W1 accepts only four-scope/eight-product typed absence and no G3 source authority. AD-48 S1 accepts current working-tree locators only. AD-48 S2 factory probing is `in_progress`/`pending` and unaccepted; its independent confirmation of `AbsentG3FactoryIdentityV1` is the sole prerequisite for conditional F0, after which fresh S2 → S3 → fresh W1 → W2 is mandatory. This adds no machine node and does not modify the 39-task manifest. The formal route remains `T0 → authority recheck → T1 → T2 → aggregate → UP2 → UP3 → UP4 → UP5 → UP6`; provider, mesh, solver, engineering, physical, search, R01–R10 and L4 remain false/zero, and documents/tests/agent/planner/runner exits never substitute for physical evidence.

## 2026-09-16 AD49–AD50 core status synchronization

AD48 F0/S2/S3 and AD49 F0/S2/S3 now have synchronized `accepted_limited` records limited to software capability and typed absence. AD48 external trust remains blocked. AD49 S3 remains gated by `blocked_external_trust_root_and_source_closure`; its four readiness 89–92 products are absent/terminal-deferred and do not publish trusted or candidate identity. G2 mapping, W3B, AD46, UP1-04B, UP2-00, B00 and B04 remain pending or blocked under their existing contracts.

No work-order node or dependency edge is added. The ordered UP1→UP2→UP3→UP4→UP5→UP6 route and all R01–R10 obligations remain unchanged. T0/T1/T2, provider, mesh, solver, engineering, physical, search and L4 credit remain closed. See the [synchronization evidence](../implementation/CORE-STATUS-SYNC-AD49-AD50/report.md).
AD50 本身当前为 `implementation_status=completed_review_pending`、`independent_review_status=pending`、`root_acceptance_status=pending`、`decision=review_pending`；本段只记录状态同步实现，不构成 AD50 验收。
