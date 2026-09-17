# 执行工作单与依赖

AD-20 chain note: UP2-00 has an independent r18 accepted_limited local result for actual-A N01/N02 schema/value projection; N07/N08 and N09 have separate local accepted_limited contract archives that do not count as formal B04 receipts; the total gate remains review_pending/accepted=false with all 50 formal B04 receipts pending; UP1-04B remains planned and still owns B00 F0-F5, formal B04 mutations, receipts, checker, and two-process replay.

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
| [UP2-00](#up2-00) | contract-only typed precompiler schema/validator | UP1-04A | 否 |
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

<a id="up2-00"></a>

### UP2-00 contract-only typed precompiler schema/validator

当前状态：`review_pending`；独立 r18 已以 `accepted_limited` 接受实际 A package 的 N01/N02 schema/value projection 局部范围；N07/N08 与 N09 另有局部 `accepted_limited` 合同归档，但不计入正式 B04 receipts；UP2-00 总门仍未接受，历史 40/50 local mutation slots 尚未完成，且全部 50 条正式 B04 receipts 仍 pending，等待后续 contract-only typed precompiler schema/validator 完成。归档：[UP2-00 acceptance](../implementation/UP2-00/acceptance.md)、[独立 r18 复核](../implementation/UP2-00/independent_review_r18/acceptance.md)。

- 前置：UP1-04A。
- 技术章：[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)；冻结义务：[19_up0_02_contract_freeze.md](19_up0_02_contract_freeze.md)。
- 输入：UP1-04A candidate-bound package、B04 N01–N10 真实 typed precompiler 字段和预注册错误分类。
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
- 输入：最终 schema、UP2-00 validator、三层新 candidate refs、B00 F0–F5 和 B04 N01–N10 mutation receipt 规范。
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

当前状态：`planned`（总门依赖 UP1-04B；UP1-04A 已 limited accepted，UP2-00 当前 ready，UP1-04B 尚未完成）。UP1-INDEX 归档：[UP1-INDEX acceptance](../implementation/UP1-INDEX/acceptance.md)。

- 前置：UP1-04B；UP1-01/02/03 由 UP1-04A 汇入。
- 技术章：[10_genome_upgrade_execution.md](10_genome_upgrade_execution.md)；验收基准：B00、B04、B11，见 [13](13_acceptance_benchmarks_and_evidence.md)。
- 汇入 UP1-04A 的共享入口与 UP2-00 的 contract-only schema/validator 输出。
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

UP2 local accepted_limited slices: N03 covers five actual-A time fields with local G1/G3 checks and retains the candidate-bound G3 time-basis gap as terminal_deferred; N04 covers five actual-A ledger fields, four local invalid-closure mutations, and retains the legal shared-owner and missing exact G1 occurrence-to-G3 account/energy-boundary join gaps. These local slices do not change the UP2-00 review_pending total gate and do not count as any of the 50 fresh formal B04 receipts. N05 and N06 remain review_pending; N10 is accepted_limited for five actual-A identity/receipt fields and same-G2-plan candidate-specific rebinding; UP2 total, B00/B04, provider, mesh, engineering, physical, and R01-R10 remain unaccepted.

<a id="ad-24-e0"></a>
### AD-24 E0/E1/E2 bounded preparation links

AD-24 is accepted_limited only as an architecture/provenance boundary; it does not change the task_manifest or the UP0-UP6 DAG. The following additive preparation links are bounded work-order guidance and each requires a separate implementation plus different-Luna review gate:

- **E0 — candidate-owned bound-input identity.** Dependency: accepted AD-24 and an actual CandidateStatePackageV5. Output: a new editable binding identity with schema/canonical/profile/binding hashes, unchanged original package hash, and explicit missing authority gaps. Do not create physical evidence or rewrite old package/evidence.
- **E1 — N05 typed declaration.** Dependency: E0. Output: authored endpoint/law/unit/sign declaration bound to actual candidate refs and source provenance. Missing authority remains terminal_deferred; present conflicts fail_closed.
- **E2 — N06 typed mapping.** Dependency: E0. Output: authored source-field-return-heat/ledger/owner-scope mapping bound to actual G1/G2/G3 fields and hashes. Missing cross-layer join remains terminal_deferred.

These links do not accept N05/N06 implementation, UP2 total, B00/B04, provider, mesh, engineering, physical, or R01–R10 credit. Formal B04 receipts and heavy execution remain separately frozen and serially executed under UP1-04B.

UP2-00C-N10 integration status: accepted_limited for the five actual-A identity/receipt fields and same-G2-plan candidate-specific rebinding, with independent r1 pass_limited evidence (80/80 plus 7/7 controls, exit 0, zero compile/provider/solver calls). N10-04 is synthetic attempted-hash only; N10-05 is fresh-receipt-only; V4 legacy provenance remains terminal_deferred. This local archive does not change the UP2-00 total review_pending gate or the requirement for all 50 fresh formal B04 receipts, checker, and two-process replay; B00/B04/provider/mesh/engineering/physical/R01-R10 remain unaccepted.

