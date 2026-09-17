# 技术来源、架构决策与待冻结事项

版本：`v4-upgrade-plan-20260914.1`。本页记录已经接受的路线选择、其依据及仍需实现验证的技术决定。技术库网页在 2026-09-14 访问核对；网页访问不等于本地软件已安装、版本已冻结或 provider 已通过验收。

## 1. 当前架构决策

| ID | 决策及理由 | 落地要求 |
|---|---|---|
| AD-01 | 三层 Genome 可版本化补齐。用户本次授权替代旧版“不得修改 Genome”的范围限制 | UP0-02 冻结版本/命名，UP1-04 迁移，旧候选和证据只读 |
| AD-02 | 自研物理语义编译、离散组装和耦合；复用成熟数值算法 | 各 lowering 有适用域和基准，不自研全部线性代数/时间积分库，不按装置家族选择方程 |
| AD-03 | 保留有界迭代，先增强每次编辑及反馈能力 | UP1–UP4 先提供可执行链，UP5 再扩大 typed edits、e-graph、QD/MCTS |
| AD-04 | 抽象拓扑、几何可实现性、离散兼容性和物理可解性分开 | 不以任意图/Betti 数/软分区直接声称可制造可求解；拓扑事件另有物理模型 |
| AD-05 | G3 早期提供合同及组件核，后期做逆设计完整闭环 | 避免要求 UP1 先做完依赖 UP2/UP3 的逆求解；UP4 必须有实际源、供能热结构回代 |
| AD-06 | 基降维是可选的局部加速路线，不是缺失模型的替代品 | UP3-03 冻结训练域、约束、误差/OOD与完整求解回退；不得因低维收敛绕开物理门 |
| AD-07 | 数学等价、数值等价、物理证据和外部原创性各有作用域 | e-graph 不把未饱和当不等价，不自动迁移 evidence；R09 仍需独立外部审查 |
| AD-08 | Sol high 只管最高层，Luna high 执行与复核 | 14 定义文件独占、派单/反馈、重计算串行、独立评审和实际模型回执 |

## 2. 成熟工具的合理位置

下表是选择方向，不是新增依赖清单或安装请求。UP2-05 必须锁定具体版本、确认 API/许可证/数据可得性，执行组件基准后再声明 provider 可用。

| 工具 | 可借鉴或复用的层 | 不能自动提供的能力 | 一手来源 |
|---|---|---|---|
| Gridap.jl | Julia 有限元弱式、函数空间与组装 | 任意等离子体闭合、全部拓扑事件或验证证据 | [官方仓库](https://github.com/gridap/Gridap.jl) |
| ModelingToolkit / SciML | 符号系统、组件组合与结构变换；数值算法由相应 SciML 库提供 | 自动理解任意新物理、任意 PDE 网格和 source hardware | [官方文档](https://docs.sciml.ai/ModelingToolkit/dev/) |
| FUSE.jl | 聚变装置集成建模和 actor 组织方式，可评估适用的物理/工程后端 | 任意抽象拓扑的总求解器；本项目 Genome 编译、证据 authority 或未支持的物理模型 | [官方仓库与架构说明](https://github.com/ProjectTorreyPines/FUSE.jl) |
| FreeGS / DESC | 当前已使用的专用平衡适配器及其适用域中的计算 | 以产品名替代完整 capability 判定；本地适配器限制也不能反推软件全部能力 | [11 的现实现与来源](11_physics_compilation_and_discretization.md) |
| egg / equality saturation | e-graph、重写、提取的算法思路 | 自动证明新物理、连续/离散/浮点无条件互换、全空间最简性 | [原始论文](https://arxiv.org/abs/2004.03082) |
| 有限元外微分 FEEC | 兼容微分复形、守恒离散与拓扑/调和自由度的数学依据 | 单靠 curl 势就覆盖任意拓扑和边界条件；任意删除零空间仍保持物理 | [Arnold–Falk–Winther 原始论文](https://arxiv.org/abs/0906.4325) |

FUSE 官方文档说明其使用 IMAS `dd` 数据结构、physics/engineering actors 和具体 use cases。能集成多个物理工程模块说明其适合集成设计，不推出它能处理所有空间拓扑。本项目入口仍由自己的 typed 合同和能力声明驱动；FUSE 如接入，作为有适用域的后端，并保留损失的信息和未满足义务。

数值方法的选择必须随问题结构决定：连续/离散对称性、守恒、边界、刚性、约束、时间尺度和所需 observables。不能单凭“Julia”“通用库”或工具名称做物理能力证明。

## 3. 当前源码核验入口

| 判断 | 代码入口 | 解释 |
|---|---|---|
| 已有类型化表示 | `src/IR/TypedAST.jl`、`OperatorHypergraph.jl` | 表达与合法性不等于所有组合已有执行器 |
| 通用 compiler 尚主要做结构/义务 | `src/RuntimeV4/Compiler.jl` | 与具体切片已能执行同时成立，不能写成整个项目无求解 |
| 场求值算子有限 | `src/RuntimeV4/FieldProgramEvaluation.jl` | 本 evaluator 延期导数，不等于其他专门空间内核没有导数 |
| 固定公式切片 | `src/RuntimeV4/FieldResidualPipeline.jl` | G2 场 artifact 与 G1 残差 AST 各自有固定结构检查 |
| 空间模型身份限制 | `src/RuntimeV4/SpatialMultiRegionV4.jl::_smr_declaration` | 必须以经过验证的兼容判定和真实执行能力取代，不能只删 guard |
| 工程逆实现未泛化 | `src/RuntimeV4/SpatialPickupEngineeringV4.jl` | 固定拾取线圈与条件 RL 不能算一般 source inversion |
| 搜索仍有限 | `src/RuntimeV4/AlgebraicGenerationV4.jl`、`Search.jl` | 当前有限 0D 后代和队列不等于完整 QD/MCTS |
| 条件 e-graph 原型存在 | `src/IR/ConditionalEGraphSaturation.jl` | 有限整程序推导，生产搜索接入和一般子表达式扩展尚需实施 |

当前基线与运行状态详细证据见 [13](13_acceptance_benchmarks_and_evidence.md)；源码会变，未来报告必须重取 HEAD、脏文件哈希和 artifact，不照抄本表日期。

## 4. UP0-02 必须冻结的技术决定

- 三层 schema/payload、canonicalization、profile 和 migration 的独立版本轴；V2/V5 拟议名不是已发布接口。
- 初始支持的算子、闭合模型、维度、区域连接、空间/时间离散、材料和源组件配置；每项有明确扩展策略。
- 方程/弱式或通量/离散/solver plan 的字段、semantic hash 和 typed 接口，不为旧 fixture 另开通用入口特判。
- 精确的量纲归一化、数值和物理门、识别/UQ协议与留出数据；建议阈值先评审再冻结，不能看结果调门。
- 外部区域、磁规范/divB、守恒传递、初值一致性及闭环收敛协议。
- backend 锁定版本、导数能力、独立性组、资源预算、运行/恢复命令与停止条件。

新增决定采用 `decision_id / task_ids / question / evidence / options / decision / scope / contract_version / invalidated_artifacts / reviewer / date` 记录。Sol 作架构裁决，Luna 维护细节。一般可逆实现选择无需重新请示用户；改变父目标或必需硬门不能由实施者自行决定。

## 5. UP0-02 Sol 架构裁决（2026-09-14）

以下裁决由 Sol 在 UP0-02 进入实现前写入。本节只冻结语义、边界和协议要求；schema 的实际内容哈希、provider manifest 哈希和 migration receipt 必须由后续 UP1 实现与运行产生，当前不预填值。

| decision_id | task_ids | decision | scope / invalidated_artifacts | reviewer / date |
|---|---|---|---|---|
| AD-09 | UP0-02, UP1-04 | 四个版本轴独立：payload schema version、canonicalization/hash profile version、grammar/capability applicability profile version、execution/evidence receipt version。任何一个轴变化都不能伪装成另一个轴的兼容升级。 | 新合同及新 fixture；V1/V4 bytes、hash、candidate identity、execution receipt 和 evidence 只读，不因新版本失效。 | Sol / 2026-09-14 |
| AD-10 | UP0-02, UP1-01, UP1-02, UP1-03 | 正式新类型命名为 G1 `MechanismGenomePayloadV2` 与 `MechanismGenomeV5`；G2 `FieldGeometryGenomeV5`；G3 external bundle `RealizationControlGenomeV5`，其内部包含 `RealizationGenomeV5`、`ControlGenomeV5`、`CoupledRealizationControlBindingV2`。这些是冻结中的新合同名，不表示源码已实现。 | 新版本路径只创建新 identity；历史 V1/V4 payload 和 receipt 不重写。现有 G1 `wire-domain:v2` 是适用域/能力标签，绝不等于 `MechanismGenomePayloadV2`。 | Sol / 2026-09-14 |
| AD-11 | UP0-02, UP1-04 | `CandidateStatePackage` 对外保留 G1、G2、G3 各一个独立 `GenomeContractRef`；其中 G3 的 external bundle ref 必须在内部携带并校验 `RealizationGenomeV5`、`ControlGenomeV5`、`CoupledRealizationControlBindingV2` 三个 child refs，以及四版本轴、schema/canonicalization/profile 标识、compatibility profile 和 candidate binding。缺失或不匹配只能得到明确 gap 与 `terminal_deferred`。 | 所有新 candidate package、migration 和 evidence join；旧 ref/hash 不被就地补字段。 | Sol / 2026-09-14 |
| AD-12 | UP0-02, UP1-01, UP2-05 | 新 operator 只能进入 candidate-owned additive registry，并绑定其版本、语义、单位/效应、capability signature 和 provider scope；禁止修改 `default_operator_registry()` 来安装结构性桥接或改变旧候选解释。 | 现有默认 registry、旧 candidate、历史 receipt 保持不变；新增 operator 没有执行证据前只能是 proposal/contract scope。 | Sol / 2026-09-14 |
| AD-13 | UP0-02, UP1-04, UP2-05 | 内部 ECF `unsupported` 只能通过显式兼容映射变成中间 `provider_match` gap 或 `resolution=terminal_deferred`，并记录 source/target、reason 和 scope；它不能成为最终 authority 的终态结论，也不能被默认为通配 provider。 | ECF bridge、provider routing、evidence authority；已有历史原生 `unsupported` 保持原值。 | Sol / 2026-09-14 |
| AD-14 | UP0-02 | B00 F0–F5、B04 十类负例和 UP1 三层最小 fixture 按 [19](19_up0_02_contract_freeze.md) 与 [up0_02_protocol.json](up0_02_protocol.json) 预注册。量纲、归一化、阈值、预算、seed、环境、independence group、claim ceiling 必须在任一结果可见前冻结。 | UP0-02 已接受但仅限 `pre_result_contract_design`；不构造尚不存在的 schema_hash、provider manifest 或物理结果。 | Sol / 2026-09-14 |
| AD-15 | UP0-02, UP1-01, UP1-02, UP1-03, UP1-04, UP2 | UP0-02 交付预结果版本轴、合同和协议设计；实际 schema hash、新鲜 B00/B04 execution、validator/checker receipt 由 UP1/UP1-04（及对应 UP2 垂直配置）生成。B01–B13 每项必须在对应正式运行前另建版本化 protocol，结果后禁止调门。 | 不缩减 R01–R10；UP0-02 已由独立复核和 Sol 接受，但 accepted scope 仅为 `pre_result_contract_design`，不授予 B00/B04、物理或父目标信用。 | Sol / 2026-09-14 |
| AD-16 | UP0-02, UP1-01, UP1-02, UP1-03, UP1-04 | B04 的五个变体仅是 `illustrative_contract_mutations_pending_schema_binding`：不是 JSON Pointer、不是可运行 suite、不是执行通过证据。正式 B04 mutation suite 必须在 UP1 schema 完成后且首次运行前另冻；UP1-04 没有真实 B00/B04 execution、checker exit 和 candidate-bound receipts 不得接受集成。 | 保留 B04 十类义务和 R01–R10；UP0-02 accepted 仅限预结果合同设计，不提前放行 B04、物理结果或父目标。 | Sol / 2026-09-14 |

UP0-02 的可审计交付和未决字段见 [19_up0_02_contract_freeze.md](19_up0_02_contract_freeze.md)、[up0_02_protocol.json](up0_02_protocol.json) 和 [UP0-02 acceptance](../implementation/UP0-02/acceptance.md)。本节不改变共享入口或 R01–R10 ledger；accepted 仅表示预结果合同设计范围，B00/B04 execution 与物理证据仍未完成。

<a id="ad-17"></a>

## 6. AD-17 版本 token 与公共 GenomeContractRef（2026-09-14）

Sol 裁决：`GenomeContractRef.version` 是合同修订 token，类型名另列；字符串相似不构成自动兼容。19 与 `up0_02_protocol.json` 中出现的类名式 version 只作为当时 illustrative pending fixture 保留，不在结果可见后回写冻结文件，也不把它们当作已通过的 schema/provider 证据。

| ref / 语义层 | 冻结的 version token | 约束 |
|---|---|---|
| G1、G2、G3 对外 Genome bundle | `v5` | 每层对外各自提供一个真正公共的 `GenomeContractRef`；G1/G2/G3 的 contract identity、schema、canonicalization、applicability 和 receipt 仍按各自域绑定 |
| G3 realization/control 外部 bundle | `v5` | 外部 bundle ref 不被 child alias 替代；内部 realization、control 和 binding refs 由附属 binding 精确列出并校验 |
| G1 payload schema | `v2` | 是独立 schema ref，不因 G1 bundle 的 `v5` 而改写成同一版本轴 |
| G3 `CoupledRealizationControlBindingV2` 及其 schema | `v2` | binding child 与 schema 使用独立 `v2` 域，不能用 G3 外部 bundle 的 `v5` 冒充 |

实现约束：公共 ref 只能由真实受控字段生成的 schema hash 与 canonical hash 构造；自定义 alias、nullable hash 或标签 digest（例如 `digest256_text('g2-schema')`）不能顶替公共 ref。尚未具备的 schema/provider 必须以独立、可消费的 `deferred` 字段表达，不能用伪造 hash 或字符串匹配清除缺口。profile hash、四版本轴、G3 realization/control child refs、`CoupledRealizationControlBindingV2` binding 和 candidate identity 必须在同一 candidate-bound 校验中精确绑定。

UP1-04 只能通过显式 migration receipt 把每个旧占位 ref 映射到新权威 ref，并记录 before/after 的完整 ref、schema/canonical/profile hash、四轴版本域及 candidate identity 重建结果；缺失、含糊或仅靠名称相似的映射必须 fail-closed。旧 evidence、旧 hash 和旧 candidate identity 不得复用。正式 B00/B04 fixture 与 suite 要在 schema 完成后、首次执行前另冻版本；本裁决不把 G1/G3 当前代码视为通过，也不改变父目标 R01–R10。

<a id="ad-18"></a>

## 7. AD-18 G3 standalone feedback authority boundary（2026-09-14）

Sol 裁决：G3 standalone admission 对 `feedback.target_contract_ref` 只检查目标层 namespace、`v5` version token 和公共 ref 的基本形状。其 `target_layer` 必须是 `G1` 或 `G2`，URI 必须落在对应的 `fusionconceptai://GenomeV5/<layer>/` namespace；错误层、错误 version token、缺失基本字段或错误 ref 形状必须 fail-closed。该阶段不把 target ref 的 schema/canonical/profile 当作跨层权威比较结果。

standalone 测试中的 fixture seed、合成的 `/feedback-target` URI 和由 seed 派生的 digest 只是不变量与负控的结构输入，永远不能充当同一 candidate 的外层 G1/G2 公共 ref。若 admission 看不到同一 candidate 的实际 G1/G2 外层公共 refs，必须单独记录 `feedback_authority_gap`，resolution 为 `terminal_deferred`；该 gap 与 provider gap 分栏，不能互相清除，也不能将结构可接受性写成 provider、工程或物理证据。

UP1-04 在收到实际三层 bundle 后负责跨层 authority join：对每个反馈目标逐字段 exact compare 完整 `GenomeContractRef`（URI、version、schema、canonical、profile）、四轴和 candidate binding，并据此重建 candidate identity。任一层、版本、ref、轴或 candidate binding 不匹配均 fail-closed；缺少真实外层 ref 时仍保留 `feedback_authority_gap`/`terminal_deferred`。该裁决不授予 B00、B04、provider、工程、物理或 R01–R10 信用。

| 阶段 | 可检查 | 必须保留的边界 |
|---|---|---|
| G3 standalone | target layer namespace、`v5` token、公共 ref 基本形状 | 无同 candidate G1/G2 外层 ref 即 `feedback_authority_gap` + `terminal_deferred`；seed/synthetic ref 不具 authority |
| UP1-04 integrated | 完整 ref 五字段（URI、version、schema_hash、canonicalization_hash、compatibility_profile）、四轴、candidate binding 的逐字段相等性及 identity rebuild | wrong layer/version/ref fail-closed；provider gap 独立；没有执行/物理信用 |

<a id="ad-19"></a>

## 8. AD-19 V4→V5 migration and package join boundary（2026-09-14）

Sol 裁决：完整 V4→V5 的 lossless mapping 当前为 `none`。G1 只有在声明驱动、逐项源字段/AST/closure/gene/canonical 证据齐全时才允许条件迁移；G2、G3 缺少目标语义或权威字段时只能 `terminal_deferred`，结构错误必须 `fail_closed`。旧 evidence、旧 hash 和旧 candidate identity 不得作为新 ref 或迁移证明。

采用 additive 强类型 `CandidateStatePackageV5`、显式 staged migration adapter，以及同一 candidate 的三层 exact join。V4 package、Compiler、Campaign 和既有运行入口保持原义和只读边界。V5 package 必须绑定三个实际公共外层 `GenomeContractRef`、每层四轴、三个实际 V5 component hashes、公共 refs、candidate binding，以及 G3 realization/control/binding child refs 与 feedback；G3 feedback 只有在同一 candidate 的真实 G1/G2 外层 refs 逐字段 exact compare 后才可关闭 authority gap。G2 wrapper 必须同时绑定 `candidate_ref` 与真实 `g2_genome_hash`；G1 candidate URI 必须 exact 相等，禁止 suffix 或字符串相似兼容。

身份重建必须由三个实际 component hashes、三层公共 refs、四轴、G3 child/feedback 和 candidate binding 的 canonical 内容生成。缺 mapping、provider 或 cross-layer authority 是独立 `terminal_deferred` gap；结构不合法、错层、错版本、错 ref 或绑定冲突是 `fail_closed`。fresh V5 且没有 legacy 输入时不得伪造 `terminal_deferred` migration receipt。存在 legacy 输入时，每个 receipt 必须记录完整 before/after ref 与 hash、四轴、字段逐项映射、identity before/after、算法版本、mapping provenance、状态和原因；旧 evidence 不复用。正式 B00/B04 suite 在最终 schema 完成后、首次执行前另冻版本。本决议不授实现、provider、B00/B04、工程、物理或 R01–R10 信用。

<a id="ad-20"></a>

## 9. AD-20 UP1-04A/B 与 UP2-00 的 ref 重建和分阶段执行边界（2026-09-14）

Sol 裁决：UP1-04A 从已接受的 G2 plan 内容构造每个新 candidate 的新外部公共 ref，URI 必须落在 `fusionconceptai://GenomeV5/G2/` namespace；随后重算 G2 的真实 schema/canonical/profile 绑定、G2 genome hash 和 typed package identity。UP1-02 历史 `urn:fusion:g2:*` fixture、ref、hash 和 evidence 保持只读，不能被新 candidate 复用、补字段或 alias；G3 必须消费该 candidate 的实际新 G2 ref。G2 plan 的语义可跨 candidate 复用，但每个 package 必须重新绑定 candidate ref、真实 `g2_genome_hash`、四轴和完整 identity。

为解除正式 B00/B04 与 UP2 schema 的循环依赖，执行 DAG 固定为：`UP1-01/02/03 → UP1-04A → UP2-00 → UP1-04B → UP1-04 → UP2-01`。UP1-04A 只有在 A-only 证据和独立复核完成后，才可按有限 scope 解锁 UP2-00；这不等于完整 UP1-04 acceptance。UP1-04A 只拥有共享入口、迁移 adapter 和 candidate-bound identity wiring；它的结果保持 `review_pending`，不能写成完整 UP1-04 acceptance。UP2-00 是 contract-only typed precompiler schema/validator：必须把 B04 N01–N10 绑定到真实字段和预注册错误分类，并提供 compile-before-provider 与 provider invocation count 接口；它不运行 solver、mesh 或 provider，不产生物理/工程信用。UP1-04B 在首次执行前冻结 B00 F0–F5 与全部 50 条正式 B04 mutations、receipt、checker、输入哈希和 two-process replay；完整 UP1-04 只有 B 阶段完成且不同 Luna 独立复核后才能接受。该拆分不改变 R01–R10，也不把任何 runner exit、文档或结构测试当作物理证据。

| 工单 | 依赖 | 允许的结论 | 明确未授予 |
|---|---|---|---|
| UP1-04A | UP1-01/02/03 | shared-entry 与 ref/identity contract wiring，`review_pending` | 完整 UP1-04、B00/B04、provider、mesh、工程、物理、R01–R10 |
| UP2-00 | UP1-04A | N01–N10 typed precompiler schema/validator contract | solver、mesh、provider、物理/工程及 B00/B04 execution |
| UP1-04B | UP2-00 | 首次执行前冻结并执行 B00 F0–F5、50 B04 mutations、receipts/checker/two-process replay | 由 runner exit 单独推出物理或父目标信用 |
| UP1-04（总门） | UP1-04B | B 完成后的三层 migration/package acceptance（另需独立复核） | R01–R10 缩减或任何未有证据的 provider/工程/物理结论 |

详见 [UP1-04A/UP2-00/UP1-04B work orders](16_execution_work_orders.md#up1-04a)。本决议只更新依赖和 ref authority 边界，不修改 UP0-02 冻结合同、UP1-02 历史证据、源码、测试或运行记录。

<a id="ad-21"></a>

## 10. AD-21 UP2-00 typed mutation 与 B04 receipt 边界（2026-09-14）

Sol 裁决：UP2-00 当前 typed-wrapper mutation 只属于 `schema_validation_only`。只有由实际 `CandidateStatePackageV5` 生成的 A factory projection 才是 source-backed；低层 `UP2PrecompilerInputV1(...)` 是 synthetic/unverified test seam，不得作为 B04 输入。UP2-00 的 partial acceptance 还必须有独立 Luna 复核，并对 actual A package 的每条已实现 mutation 记录 source-derived `error_code`、`error_path`、mutated value/hash 和 compile/provider/solver counters；fixture 的 `expected_error` 只能是断言目标，不能成为分类或路由来源。

UP2-00 total gate 仍要求 N01–N10 共 50 条 mutation 均绑定真实 source field 和预注册分类。缺 authoritative port、unit、time、account、source 或 migration receipt join 时保持独立 gap 与 `terminal_deferred`，不得用 synthetic value、标签路径、复制 expected label 或旧 evidence 补齐。

UP1-04B 首次执行前必须冻结 candidate-bound mutation envelope。每条 receipt 至少绑定 baseline `CandidateStatePackageV5` hash、精确的 G1/G2/G3 或 UP2 precompiler source ref/hash/path/type、原始 typed value、mutated typed value、mutation id、schema/canonicalization hashes，以及由真实 source/invariants 推导的 classification。若 typed constructor 在构造前拒绝非法值，receipt 仍必须绑定真实 baseline 与实际 attempted/mutated typed value；不得用无输入的异常标签代替 receipt。禁止 synthetic low-level input、复制 expected_error、label routing、reused evidence 或 archive pollution。

只有 schema freeze 后新鲜生成的 50 条 candidate-bound receipts、checker 证据和两个独立进程 replay 才能进入 UP1-04B 复核；compile/provider/solver 为零只能证明结构短路，不授予 B00/B04、工程、物理或 R01–R10 信用。AD-21 不改变执行 DAG、任务状态或父目标范围。

<a id="ad-22"></a>

## 11. AD-22 N03/N04 跨层时间与账本 authority 边界（2026-09-14）

Sol 裁决：19 与 `up0_02_protocol.json` 的 N03/N04 五行仍是 `illustrative_contract_mutations_pending_schema_binding`，不是可直接消费的 JSON Pointer。当 V5 没有对应字段时，不能把说明性路径静默映射为新字段，也不能删减这十类失败义务。当前 `TypedPrecompilerValidatorV1.jl:29-40` 的五行 N03 与五行 N04 是 provisional candidate-bound projection locators；它们在正式 schema freeze 前必须保留并逐行绑定真实 source field、mutation value、分类与 invocation receipt。

G1 的局部时间合同已经权威：`MechanismGenomePayloadV2.jl:83-95` 对 equation 的 `operator_ref` 做 candidate-owned exact lookup，并检查 `temporal_kind in operator.temporal_kinds` 与 `derivative_order <= max_derivative_order`；`MechanismGenomePayloadV2.jl:115-184` 继续检查 typed expression、状态时间/导数、occurrence、closure ledger 和 balance。G3 的事件局部合同只权威到类型与范围：`RealizationGenomeV5.jl:306-315` 限定 trigger 枚举和非负 exact Rational time。G3 event 没有 equation time basis；静态 G1 方程不能单独使 G3 scheduled/event 失效。只有新增的、candidate-bound 且内容哈希受控的事件时间政策才能判定跨层 time mismatch；缺少该 authority 保持 `terminal_deferred`，intrinsic enum/range 错误才 `fail_closed`。

G3 的 account/entry/closure 局部合同保持独立：`RealizationGenomeV5.jl:435-449` 检查 closure account_ids 非空且唯一，`:467-488` 检查 typed/unique IDs，`:504-565` 检查 port/account/entry/component 引用、单位、容量、closure domain 与余额。profile 文本的 `owner_uniqueness`（`:132-140`）目前没有对应 executable check；现有测试明确允许 shared owner（`test/GenomeV5/G3/up1_g3_contract_tests.jl:245-252`）。因此 owner 字符串相等不等于 duplicate accounting。N04 的 double-count 分类必须先冻结 owner uniqueness 的 account/closure scope，并要求 G1 occurrence ledger_id 到 G3 account/entry 及 energy boundary 的 exact mapping；缺 authority 仅为独立 `terminal_deferred`，不能由现有 G3 balance 检查代替。

最小 additive authority 采用独立、版本化、内容哈希的 N03 time authority 与 N04 account-closure authority。每条声明绑定同一 candidate 的 G1/G3 public refs、component hashes、四轴、精确 source locator/type/value 和 schema/canonical/profile hash。结构类型或枚举错误必须 `fail_closed`；缺 time basis、owner scope 或 ledger join 必须保留 gap 与 `terminal_deferred`。该 authority 只服务 contract-only precompiler admission，不调用 compiler/provider/solver，不产生 B04、工程、物理或 R01–R10 信用。N03/N04 的实现应各写入互不重叠的新 UP2 文件集合，后续再由 UP2 formal validator 接入；不得修改旧 V4、default registry、已有 N09 文件或历史 evidence。

本裁决只写入架构语义和证据边界，不改变 UP0–UP6 DAG、任务状态、UP2 总门或父目标范围。

<a id="ad-23"></a>

## 12. AD-23 UP2 N10 identity/receipt mutation schema boundary（2026-09-14）

Sol 裁决：当前 UP2-00 的 N10-01..05 rows 仍是 formal schema freeze 前的 provisional fixture/spec rows。它们必须保留为历史登记，不得在原地重新解释为已通过的正式 B04 rows；任何分类、locator、source type 或 mutation recipe 修订都必须生成新的 schema/hash/fixture 版本，并保留旧 rows、attempts 和失败记录。

本次审计确认 fresh CandidateStatePackageV5 确实提供以下可消费字段：

- component_identity.g1_ref.schema_hash 和 component_identity.g2_ref.canonicalization_hash 的实际值均为 Digest256；但 component_identity.g1_ref/g2_ref 是由 _v5_ref_identity 生成的五字段 identity NamedTuple，而不是原始 GenomeContractRef。
- component_identity.g3_child_refs.binding 也是 identity NamedTuple。实际权威 typed child ref 位于 package.g3.binding.contract_binding.contract_ref；GenomeV5Integration.jl:62-68 生成 child identity，:80-85 定义五字段 identity。N10-03 当前 ...binding::GenomeContractRef locator/type 与实际 component identity 字段不一致，必须在新版本中明确 actual typed child ref 与 identity NamedTuple 的 exact comparison，或改为准确的 source locator/type。
- package.candidate_hash::Digest256 由 CandidateStatePackageV5.jl:219-223 对 package_version、candidate ref、component identity、version axes 和 migration receipt canonical 化生成。
- package.migration_receipt.candidate_identity_after::String 在 fresh factory 初始为 pending receipt 字段（CandidateStatePackageV5.jl:116-120），随后由 integration 在 GenomeV5Integration.jl:323-333 按实际 identity/axes 重建；fresh receipt 的 records 为空、status=:pending，不能作为 legacy mapping 证据。

AD-19/AD-21 的分类边界必须落实到新版本：若实际 A 中存在 ref、hash、candidate identity 或 receipt identity，foreign/stale value mismatch 是可由实际对象比较得出的结构错误，统一归为 invalid_type + fail_closed（必要时保留精确 field path）。terminal_deferred 仅用于缺失 mapping、authority 或 provenance，尤其是没有真实 V4 source receipt 的 legacy migration。现有 fixture 中 N10-02、N10-03、N10-05 把错误值预注册为 terminal_deferred，与 AD-19 的结构错误边界冲突；新 fixture/classifier 必须修订并保留旧登记为历史 pending，不得复制旧 expected_error。

N10-01、N10-02 和 N10-04 的 source-backed rejection 应分别将 component identity ref hash、实际 G2 ref canonical hash、以及按 package canonical formula 重算的 candidate hash 与 mutated value 比较。N10-03 必须对实际 G3 binding child GenomeContractRef 的 URI、version、schema hash、canonicalization hash、compatibility profile 五字段与 component identity projection 精确比较。所有 classifier 必须从 actual A package 和 cross-field identity invariant 推导 code/path；fixture 的 expected_error 只能作为测试 oracle，不能驱动分类或路由。

N10-05 在当前 fresh A 上只能形成真实的 candidate identity-after mismatch attempted mutation：它可保存 baseline package hash、原始 receipt 字段和 attempted foreign/stale candidate_identity_after，然后由重算 identity 推导拒绝。由于 fresh receipt 没有 legacy records，这不能声称覆盖 stale legacy receipt。真正的 legacy receipt mutation 必须另有非 placeholder 的 V4 source ref、完整 before/after refs 和 hashes、axes、field mapping、identity rebuild、algorithm revision 和 provenance；缺任一项继续 terminal_deferred。现有 UP1-04 integration test 对 stale receipt constructor rejection 的覆盖（test/GenomeV5/UP1-04/up1_04a_integration_tests.jl:165-180）只能作为历史结构证据，不能替代 N10 candidate-bound receipt。

新增 N10 projection work order 必须使用独立版本化 source/fixture/test/runner/archive 文件。它只接受 actual CandidateStatePackageV5 factory input，输出每条 mutation 的 baseline package hash、精确 source ref/hash/path/type、原始与 mutated typed value/hash、source-derived error code/path、mutation/schema/canonical hashes、receipt identity 和 compile/provider/solver counters。constructor 在拒绝前短路时也必须保存 baseline 与 attempted value。测试必须包含同一 G2 plan 在不同 candidate 下重建 ref/hash/identity 后的 foreign reuse 负控、G3 child binding 错层/错 ref 负控、candidate hash 重算负控和 fresh receipt identity mismatch 负控；不以低层 synthetic constructor、旧 evidence 或自报标签补齐 N10。

本决议只冻结 UP2 N10 的 schema/分类/receipt 设计边界，不接受 UP2-00 总门，不改变 UP0–UP6 DAG、任务状态、B00/B04 义务或 R01–R10。新工单仍是 schema_validation_only、review_pending、accepted=false；不授予 provider、solver、mesh、工程、物理或 R01–R10 信用。正式 B04 前必须完成新 schema/hash freeze、fresh candidate-bound receipts、checker 与不同 Luna 独立复核。

<a id="ad-24"></a>

## 13. AD-24 N05/N06 cross-layer physical-binding authority boundary（2026-09-14）

Sol 裁决：当前 actual `CandidateStatePackageV5` 没有 N05 所需的权威 interface flux/traction/current endpoint、双端 sign 或 flux-unit 来源，也没有 N06 所需的 dimensioned source→field→return/heat/ledger/owner-scope exact join。UP0-02 与现有 UP2 的 N05/N06 五行 provisional rows 必须保留为历史登记，不能在原地解释为 formal B04 receipts 或物理闭环。

只读 source audit 确认：G2 `G2InterfaceV2` 只有 `interface_ref`、左右 region、axis、coordinate、normal、continuity、transfer_kind；`normal` 是几何方向，不是 flux sign，interface 没有 flux endpoint 或 `UnitSignature`。G1 equation/occurrence 的 units、coefficient、port side/index 和 ledger id 是另一组 typed source；`eq.input_units[1]` 不能被复制成 flux unit。当前 fixture 中 G1 可出现 dimensionless `temperature`/`energy` 类 occurrence，而 G3 resource network 使用 V/A/W 的 source/load/return/heat units；源码没有可审计的 dimensioned conversion 或 source-to-field law，字符串相同或 G3 局部 balance 成立均不能完成跨层 join。

G3 `resource_ports`、accounts、entries、closures 和 control-resource links 有独立的 typed structural validator：它可以检查 id/ref resolution、kind/direction、expected unit、capacity、account/entry relation、closure domain 和 Rational balance。该局部合同不建立 G1 occurrence→G3 account/entry/energy boundary 的 authority，也不证明 source→field→return/heat 链路。account `owner` 相等不能自动判为 double count；shared owner 是合法边界。缺少版本化 owner scope 和 exact occurrence join 时保持独立 `terminal_deferred`。

当前 UP2 N05 wrapper 的 `pending-port:left/right`、`normal/-normal` 和 `eq.input_units[1]` 都不是 authority。当前 N06 的 G3 tuple/index locators 只指向局部 typed objects，不能证明跨层 source/field/return/heat mapping。分类边界固定为：实际已存在的 typed declaration 若违反其局部或声明不变量，`fail_closed`；缺 source、conversion law、endpoint、owner scope、cross-layer mapping 或 provenance，`terminal_deferred`。本裁决不要求用 unknown-field 拒绝来伪造 N05/N06 coverage，也不削减十行义务。

最小 additive、可编辑、candidate-owned authority 命名为 `UP2CandidatePhysicalBindingV1`。它覆盖实际 `CandidateStatePackageV5`，不修改 V5/旧 V4 入口、default operator registry、旧 evidence 或旧 provisional rows。bound input 必须包含同一 candidate 的完整公共 ref、package hash、三个完整公共 `GenomeContractRef`、component hashes、四轴，以及该 binding 自己由真实 schema/canonicalization/profile source 计算的 content hash；该 binding hash 必须参与新 bound-input 的 canonical identity，但不得回写或重算原 `CandidateStatePackageV5.candidate_hash`。G2 interface 的 v2 `QualifiedRefV1` 只能作为 binding 内的 child locator，绝不能替代 G2 outer 的完整五字段 `GenomeContractRef`。所有 mutation receipt 还要保存真实 source ref/hash/path/type、原始和 attempted typed value/hash、分类与 zero compile/provider/solver counters。

该 authority 的 N05 部分必须由明确 authored 的 typed flux/traction/current law、左右 endpoint refs、G2 interface child ref/regions、由 flux semantics 声明的 signs、每端真实 `UnitSignature` 与 provenance、以及 G1 equation/operator/occurrence locator 构成。没有 endpoint、law、sign 或 unit provenance 时只能 `authority_gap`/`terminal_deferred`；声明存在但 interface、candidate、方向、sign、unit 或 ref 不一致时 `fail_closed`。

N06 部分必须由 authored typed conversion/source-field-return-heat/ledger owner-scope mapping 构成，并精确绑定 G1 occurrence/closure、G2 region/boundary、G3 resource port/entry/account/closure/link refs，以及 dimension/unit transformation law。缺 mapping、law、provenance 或 owner scope 时 `terminal_deferred`；实际 ref、单位、方向、容量、closure balance 或声明关系冲突时 `fail_closed`。只写下自洽 declaration 仍只是 contract authority，不是 provider、mesh、工程或物理证明。

N05、N06 和 shared bound-input 必须使用互不重叠的新版本化 source/fixture/test/receipt/checker 文件集合；后续实现由不同 Luna 独立复核，正式 B00/B04 另行在首次执行前冻结。AD-24 不改变 UP0–UP6 DAG、任务状态、UP2 总门、50 条 formal B04 义务或 R01–R10；当前 AD-24 的 architecture/provenance boundary 为 `accepted_limited`，E0/E1/E2 实现与物理仍 pending，不授予 implementation、provider、mesh、engineering、physical 或 R01–R10 信用。

<a id="ad-25"></a>

## 14. AD-25 UP2 additive module seam（2026-09-14）

G-I0 的实现只增加一个 UP2 module entry：它先调用现有 `load_genome_v5_components!()`，确认 G1→G2→G3 顺序，再按 `PrecompilerInvocationCounterV1` → `TypedPrecompilerContractV1` → `TypedPrecompilerValidatorV1` → E0 bound-input → N03–N10 的稳定顺序注册定义。每个文件以实际类型或函数 sentinel 做幂等保护，focused runner 已先加载的定义不会被重复 include。修复后的 focused runner 还必须在首次共享加载前手工 include 一个稳定 UP2 定义并断言类型 identity 保持不变；独立 fresh-process probe 必须观察首个真实 UP2 定义已注册后注入的后续 include 失败、同进程 `:failed` terminal state 和第二次调用拒绝。

`src/FusionConceptAI.jl` 与 `GenomeV5/Integration/GenomeV5Integration.jl` 只承担窄注册：导出 UP2 entry API，并公开既定 G1/G2/G3 component dependency order。该 seam 不自动构造 candidate、不调用 compiler/provider/solver/mesh、不改变 V4 入口或 `default_operator_registry`；入口可以注册当前 N05/N06 定义，但不执行或关闭其语义 admission，N05/N06 的可变实现仍须在其自身 schema freeze 后由后续工单验收。模块加载成功只证明定义注册与入口 wiring，不证明任何 source authority、B04、工程或物理结果。

本决议不接受 UP2-00 总门或 G-I0 实现本身；当前工单保持 `review_pending`，必须经过静态保护检查、一次经 Sol 串行放行的 focused runtime，以及不同 Luna 独立复核后才能记录有限实现状态。计数器构造值为零只支持静态 wiring 边界，不能替代 downstream spy 或执行证据。UP2-00 → UP1-04B → UP1-04 依赖链与全部 50 条 formal B04 义务保持不变，R01–R10 不缩减。

<a id="ad-26"></a>

## 15. AD-26 E1/E2 additive authority-context and dual-status boundary（2026-09-14）

Sol 裁决：E1 的 typed authored N05 declaration 与 E2 的 typed authored N06 mapping 只能在 actual A + accepted-limited E0 bound-input identity 之后作为 additive、candidate-owned、content-hashed extensions 产生。E0 v1 的 `n05`/`n06` 字段仍必须为 `nothing`；原 `CandidateStatePackageV5.candidate_hash`、E0 `binding_hash` 与 E0 `bound_input_hash` 不回写、不重算、不就地补字段。G-I1 可以定义独立、版本化的 authority-context hash；其输入必须显式包含完整 same-candidate A/E0 refs 与 hashes，以及独立的 E1/E2 extension content hashes。每个 present E1/E2 extension payload 与每个 typed absent marker 都必须在 context payload 中显式携带自身的 `schema_hash`、`canonicalization_hash` 与 `compatibility_profile_hash`；extension content hash 是独立输入，不能由这些字段的相似命名或隐式默认值代替。任何 ref、hash、extension content、absent marker、schema、canonicalization 或 profile 变化都必须重建 context identity。

G-I1 必须沿用双状态轴。`contract_admission` 只描述 sourced typed declaration 的同候选 refs、单位/方向、exact local joins 与可审核错误分类，允许值为 `declared_consistent`、`fail_closed`、`terminal_deferred` 或 `program_exception`；`physical_resolution` 独立保持 `unknown` 或 `terminal_deferred`，只有后续适用 provider、mesh、solver、独立物理与工程证据才可改变。声明、结构测试、runner exit 或 mutation receipt 不得把 physical status 推升。

N05/N06 baseline 缺 law、endpoint、conversion、owner 或 provenance 时必须保持 `terminal_deferred`；存在声明且局部自洽不等于真实物理 authority，typed mutation 的 `fail_closed` 只证明合同拒绝。G-I1 的统一 50 行可以记录 local classification 与 unresolved gaps，但不得把历史 provisional rows 或 E1/E2 本地十行转为正式 B04。G-I2 与 UP1-04B 仍必须另行产生新鲜 50 条 candidate-bound receipt、checker 与 two-process replay。

本裁决不缩减 R01–R10，不授予 UP2 total、B00、B04、provider、mesh、engineering 或 physical 信用，也不改变 UP0–UP6 DAG。E1/E2、G-I1 与后续 G-I2 均需独立复核；本节只冻结 authority-context、status 与证据边界，不回写旧 V5/E0 identity，不改变旧 implementation、test 或 receipt。

<a id="ad-27"></a>

## 16. AD-27 H0/H1 dimensioned cross-layer law authority boundary（2026-09-14）

本决议冻结下一层物理编译的架构边界，不接受任何实现或物理结果。H0 是候选体自有、版本化、独立 content-hashed 的 `G1→G2→G3` source/field/return/heat/ledger 带量纲定律声明。它必须绑定实际 `CandidateStatePackageV5` 与 E0 bound-input、同一 candidate 的四轴、完整 G1/G2/G3 public refs 与 component hashes，以及精确的 G1 occurrence/equation/operator、G2 region/interface/boundary、G3 port/account/entry/closure/link/feedback endpoints。若 E1 authored extension 缺席，authority context 必须显式携带 typed-absent marker 及其 `schema_hash`、`canonicalization_hash`、`compatibility_profile_hash` 和 absence-content hash；不得以隐式默认或伪造 extension 形成依赖。

H0 的 declaration payload 必须可编辑且自身有 schema/canonicalization/profile/content hash，并显式包含 unit equation、变量与端点、scale/efficiency/calibration provenance、方向与符号约定、source→field→return/heat/ledger 的能量/热守恒关系，以及适用范围和 owner scope。`normal`、`pending-port`、`eq.input_units[1]`、G3 局部 balance、静态 rule-token `law_hash` 或与实际源不相连的 URI 都不是物理来源。当前 N06 audit 已确认 actual G1 occurrence 可为 dimensionless，而 G3 source/load/return/heat 使用 V/A/W-like units；没有真实 dimensioned conversion/source law 时，mapping 保持 typed absent/`terminal_deferred`，不能把本地合成例升格为 source-backed 或 physical。

分类边界固定为：声明缺失、输入或 provenance 缺失为 typed absent/`terminal_deferred`；声明存在但 ref、candidate、axis、endpoint、单位、方向、符号、law equation、守恒关系、capacity 或 owner scope 矛盾为 `fail_closed`；未预期内部异常为独立 `program_exception`。`contract_admission` 与 `physical_resolution` 仍完全分离；即使 H0 declaration 自洽，也只代表可审计的合同 authority，不代表 provider、mesh、solver、工程或物理闭合。

H1 必须由独立实现复算 H0：不得复用 H0 的 expected-row helper、分类 helper、合成 fixture 或 declaration constructor 来生成 expected receipt。H1 应从冻结 actual A/E0/source payload 重新解析端点、单位方程、变量、方向/符号、scale/efficiency/calibration provenance、守恒关系和所有 hashes，并拒绝 foreign/stale refs、错轴、错端点、错单位、错 law/content hash、遗漏/重复行。H0/H1 的首次正式出口仍由 G-I2/UP1-04B 冻结并执行 B00 F0–F5、N01–N10 五十条 fresh candidate-bound receipts、独立 checker 和两个 fresh processes 的 canonical replay；历史 local rows、schema inventory、合成例和单进程 runner exit 都不能替代该门。

H0 的实现文件、fixtures、receipt、checker 和 H1 文件必须使用互不重叠的新版本化集合。原始 V5、E0 binding/bound-input hash、旧 N05/N06 provisional rows 和旧 evidence 不回写；H0 binding/law hash 只能进入新的 downstream bound-input/context identity。AD-27 经不同 Luna R1 architecture 与 R2 provenance `pass_limited` 复核后，由 Sol 接受为 `accepted_limited` architecture/evidence boundary；H0/H1 实现与真实带量纲 law 仍未接受。不改变 UP0–UP6 DAG、UP2 总门、UP1-04B 形式收据义务或 R01–R10，也不授予 B00、B04、provider、mesh、engineering 或 physical 信用。

<a id="ad-28"></a>

## 17. AD-28 UP2-01 upstream preparation and acyclic new-candidate rebinding (2026-09-15)

状态：`accepted_limited`；范围仅为架构、无环排期与证据边界；不运行 Julia/DESC。不同 Luna R2 `pass_limited`，Sol 接受本范围；执行节点仍 `planned`/`proposal` 且 `accepted=false`。

Sol 架构决议草案：新增三张彼此可并行、分别依赖已接受 UP1-01/02/03 的 versioned upstream work order：

- `UP2-01-G1-DIFFUSION-V1`：冻结 candidate-owned 3-D `u`、`K(x)`、`f`、typed `GRAD/DIV`、units、closure、applicability 和 source-derived negative controls。
- `UP2-01-G2-METRIC-BOUNDARY-V1`：冻结 chart→metric、executable mesh/basis/quadrature、face orientation 与 executable boundary value/ownership。
- `UP2-01-G3-SOURCE-FEEDBACK-V1`：冻结 same-candidate source/return/heat/ledger law、feedback target、source ID、units、owner scope 与 external authority。

三张声明先冻结为 UP1/UP2-00 schema-extension preparation，不宣称 UP2-01 执行通过。AD-28 当时的历史基础排期记录为先由 `UP1-04A-VNEXT` 依赖旧 UP1-04A limited structural boundary与三张新声明，创建 fresh actual candidate，重建三层 refs/hashes/axes、package、E0、G-I1A、E1/E2 与 UP2 sources/identities；该历史表述由 AD-30 的 T0/T1/T2 分层合同细化，不得绕过这些节点。旧 UP1-04A、G-I1A、N05、N06 和 UP2 local `accepted_limited` receipts 仅保留其旧候选历史范围，不能复用为新候选正式 B00/B04。

AD-28 历史基础机器 DAG 固定为：

`UP1-01/02/03 → {UP2-01-G1-DIFFUSION-V1, UP2-01-G2-METRIC-BOUNDARY-V1, UP2-01-G3-SOURCE-FEEDBACK-V1} → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01`。

当前 AD-30 正式 VNEXT DAG 为：`UP1-04A + G1/G2/G3 → T0 → T0-AUTHORITY-RECHECK → T1 → T2 → UP1-04A-VNEXT → UP2-00`；AD-28 的直接链仅作为历史基础排期保留。T0 authority recheck 是新增的 T0 输出后、T1 前置 gate；T0 本身不改。

每次 upstream Genome 变化都必须重新冻结候选、重建所有受影响 identity/receipt/hash，并重新冻结正式 B00 F0–F5、50 条 B04 fresh receipts、checker 与 two-process replay。任何实际 source authority 缺失保持 typed `terminal_deferred`；现有 actual A 的 G1 `u/K(x)/f`、G2 executable metric/mesh/face ownership 与 G3 feedback authority 缺口不得由文档填补。UP2-01 full compiler/physical、provider、mesh、工程和 R01–R10 均不授信。状态归档见 [AD-28 acceptance](../implementation/AD-28/status_sync_r3/acceptance.md)。

<a id="ad-29"></a>

## 18. AD-29 Python environment reinstallation and fresh provider receipt gate (2026-09-15)

状态：`accepted_limited`；范围仅为环境证据门与 contract-only 规划边界；`accepted=true` 仅指本架构范围。不同 Luna independent_review_r1 为 `pass_limited`，Sol 接受此有限范围；不授权 provider、mesh、物理或相关组合执行，执行节点仍 `planned`/`accepted=false`。

UP1/UP2 的 contract-only 静态工作可以继续。未来 `UP2-01` 的 provider、mesh、物理和相关组合执行必须先建立 fresh candidate-bound environment receipt，再按串行规则执行 reimport、有限 replay、provider 或物理命令。该 receipt 至少要绑定当前 source/inputs/candidate identity、解释器路径与 SHA256、实际导入模块路径与 SHA256、完整依赖版本/构建/channel 或 pip metadata/hash、外部源码树内容摘要（适用时）、命令、退出码、stdout/stderr/artifact hashes、适用 profile、限制和 classification；缺失时只能保持 `review_pending`/`terminal_deferred`，不能沿用历史 receipt。

环境角色必须按真实边界记录：FreeGS 当前 venv 开启 `include-system-site-packages`，因此 base 的 NumPy/SciPy/h5py 等可见包必须进入 receipt，不能只记录 FreeGS 版本；VMEX 与 Pleiades 的安装源在仓库外，必须记录各自 external source tree 的路径、版本/来源和完整 tree digest；CQL3D prefix 没有 Python，必须记录 C/Fortran/NetCDF/HDF5 构建工具链，不能伪造 Python environment。DESC `.venv-desc` 的 `jax-finufft` 缺失是固定边界 profile 已声明的范围限制；NUFFT 路径保持 `unsupported`/`terminal_deferred`，本决议不要求现在安装它。

历史 provider/物理收据继续有效于其原始环境、source、inputs 和运行范围，但不能自动晋升为当前 checkout 的可复现证据。AD-29 保留 AD-28 的历史基础机器 DAG `UP1-01/02/03 → {UP2-01-G1/G2/G3} → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01`，不新增 task，不缩减 R01–R10；当前 VNEXT 执行必须遵循 AD-30 正式 DAG `UP1-04A + G1/G2/G3 → T0 → T1 → T2 → UP1-04A-VNEXT → UP2-00`，`UP2-01`、provider、mesh、物理和相关组合均保持 `accepted=false`，B00/B04、工程、物理与 R01–R10 仍独立受门控。原始提案见 [AD-29 proposal](../implementation/AD-29/proposal.md)，接受范围见 [status sync R2](../implementation/AD-29/status_sync_r2/acceptance.md)，审计与状态证据见 [status sync R2 evidence](../implementation/AD-29/status_sync_r2/evidence_manifest.json)。

<a id="ad-30"></a>

## 19. AD-30 VNEXT semantic declaration transport and package boundary（2026-09-15）

状态：`accepted_limited`；`resolution=accepted_limited`；`accepted=true`（仅限无损声明传递合同、T0/T1/T2 排期和证据边界）。不同 Luna R2 已 `pass_limited`；本接受不授予实现或运行信用；后续实现仅按有限工作单和独立审查门推进，不授予 UP2、B00/B04、工程、物理、搜索或 R01–R10 信用。T0/T1/T2 执行节点继续保持 `planned`/`proposal`、`accepted=false`；既有 `UP1-04A-VNEXT` 主工单重述为 T2 后的综合冻结/独立验收汇聚门，不重复实施 T0/T1/T2。

### 源码审计结论

现有三种 concrete V5 Genome 不能无损承载三张新的 V1 声明。G1 V1 显式保存 candidate-owned `u`、有界 diagonal-affine `K(x)`、`f`、typed `GRAD/K_APPLY/DIV`、残差符号、source payload/hash 和 closure/applicability 字段（`src/GenomeV5/G1/DiffusionDeclarationV1.jl:78-117,167-225,229-325`），而现有 G1 payload 只有 typed states/equation plan/profile，且 V5 equation 拒绝 v1 operator ref（`src/GenomeV5/G1/MechanismGenomePayloadV2.jl:3-43`、`src/GenomeV5/G1/EquationPlanV2.jl:120-192`）。

G2 V1 显式保存 chart map、Jacobian、派生 metric、exact quadrature points/weights、逐面 normal/value/unit/ownership 和 authority（`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl:14-36,70-116,137-217,354-475`），而现有 G2 plan 只保存 chart token、mesh cells/basis/quadrature token 和无 value 的 boundary patches（`src/GenomeV5/G2/FieldSpacePlanV2.jl:3-21,67-171`）；V1 qrefs 也不能直接进入 V5 的 v2 qref gate（`src/GenomeV5/G2/SpatialGrammarProfileV2.jl:14-29`）。

G3 V1 显式保存 source/field/return/heat law、conservative split、entry-based ledger closure、owner/sign/direction 以及 feedback target path 和 authority ref/hash/status（`src/GenomeV5/G3/G3SourceFeedbackLawV1.jl:72-265`）。现有 G3 resource entries 按 account/port/component 建模，feedback channel 不保存上述完整 law/authority 字段（`src/GenomeV5/G3/RealizationGenomeV5.jl:254-268,415-450`、`src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:22-94`）。

当前 `G3SourceFeedbackLawV1` 本身没有 realization、control 或 binding child refs；这些 children 不能写成已由 G3 V1 保留或已构建。T0 对这三个 child 必须携带 typed-absent marker 与独立 `terminal_deferred` gap。只有 fresh same-candidate 的真实 child source/identity/ref/hash 全部提供并独立复核后，T1 才能填入 child identity；在此之前不得用 G3 V1 的 source/feedback declaration、fixture 或合成 ref 代替 children。

现有集成边界还硬要求 `MechanismGenomeV5`、`FieldGeometryGenomeV5`、`RealizationControlGenomeV5` 三个具体类型（`src/GenomeV5/Integration/GenomeV5Integration.jl:133-147`），`CandidateStatePackageV5` 对三层 concrete types 做同样检查（`src/Contracts/CandidateStatePackageV5.jl:201-216`）。因此禁止 ref-only adapter、fixture authority 或把 V1 声明压缩为旧 ref；这会丢语义并且不能形成合法的旧 V5 package。旧 concrete V5、旧 `CandidateStatePackageV5`、旧 receipts 和旧 hash 保持原语义只读。

### VNEXT 分层

T0 是 additive、同一 fresh candidate 的 exact typed declaration transport。三张声明必须各自携带 `QualifiedRefV1` `version=v5` 的同一个 `candidate_ref`，并逐项 exact-equal；transport 必须原样保留各声明已有的 source ref/payload/content、各自 `source_hash`（或由 source payload canonical body 得出的 content hash）和 `declaration_hash`。T0 必须定义 canonical bundle hash，覆盖三张声明的完整 semantic body、source/declaration identity、candidate ref、四轴和 child/feedback 状态，不能只 hash ref 标签。source rebinding 或任一声明编辑必须重算所有受影响 source/declaration/bundle hashes 与 candidate identity；缺失 source/authority/axis/child 为 typed absent/`terminal_deferred`，冲突为 `fail_closed`。

四轴必须逐层显式记录并绑定真实来源：`payload_schema_version`、`canonicalization_profile_version`、`applicability_profile_version`、`evidence_receipt_version`。T0 必须对每层四轴做逐项 equality，禁止以层名、版本字符串相似或默认值代替；轴缺失为 `terminal_deferred`，轴值冲突为 `fail_closed`。G3 V1 的 feedback 可保留 `target_layer`、`target_path`、`quantity`、`unit`、`direction`、`sign`、`source_id`、authority ref/hash/status/attestation；target 指向同候选 G1/G2 的错误 ref 必须 `fail_closed`，裸 `actual` 且未有 trusted receipt 必须 `fail_closed:unattested_authority`。三个 G3 realization/control/binding child 在未有真实同候选 source/identity 前保持 typed absent/`terminal_deferred`。

T0 不能直接送入旧 `CandidateStatePackageV5`，不能改变 `default_operator_registry()`，也不能复用旧候选 receipts。

T1 新增版本化 `CandidateStatePackageV5Next` 与对应 integrator，明确作为 AD-19 additive strongly typed package successor，完整承载三张声明及其 child/feedback identity。T1 package hash 必须覆盖 `candidate_ref`、三张完整 declaration semantic bodies、source/declaration/bundle identity、四轴、G3 child/feedback typed-absent 或 actual 状态，以及自身 schema/canonicalization/profile hashes。T1 不复用旧 package hash、旧 migration receipt 或旧 candidate identity；必须在 fresh candidate 上完成三层 exact join、component/declaration hashes、四轴和 authority provenance 重建。T1 必须同时依赖 T0 exact bundle 与独立 authority recheck；只有真实同候选 realization/control/binding children 的 source/identity/ref/hash 完备且 recheck checked-present 后，T1 才可把 G3 child 状态从 typed absent 提升；否则保持 `terminal_deferred`。

`CandidateStatePackageV5`、旧 shared entry、`default_operator_registry()`、旧候选 hash/receipt 和旧 migration boundary 均保持只读；V5Next 不得通过放宽旧 constructor、共享入口或 ref-only adapter 获得兼容。无 legacy input 的 fresh package 必须使用新的 no-legacy/pending 或 typed `terminal_deferred` migration receipt，不能伪造 deferred mapping；若有 legacy input，receipt 必须逐项记录完整 before/after refs、hashes、四轴、field mapping、identity rebuild、algorithm revision 与 provenance，缺失则保持 deferred。

T2 在 T1 新包上重建 E0/G-I1A/E1/E2/UP2 identities；每一份新 identity/receipt 必须绑定同一个 fresh candidate、canonical bundle/source identity、三层 declaration/component hashes、逐层四轴、G3 child/feedback 状态和 authority provenance。T0/T1/T2 任一缺 source authority、真实 child 或轴来源保持独立 typed `terminal_deferred`；结构冲突保持 `fail_closed`，不得在 T2 identity rebuild 中晋升。只有该 identity chain 经独立复核后，才可冻结 formal B00 F0–F5、50 条 fresh B04 receipts、checker 和 two-process replay。完成 T2 仍不自动授予 provider、mesh、工程、物理或 R01–R10 信用。

### 退出门与边界

- AD-30 的架构边界为 `accepted_limited`，但 T0/T1/T2 执行节点保持 `proposal/review_pending/accepted=false`，不因本文关闭。
- T0 退出门是 schema/hash recipe、同一 fresh candidate `QualifiedRefV1` exact join、source/declaration/content/bundle hash round-trip、四轴逐项 equality、source-rebinding hash rebuild、G3 typed-absent child/feedback authority gap 和 contradiction negative controls 经独立复核。
- T1 退出门是新 package/integrator 对完整三声明、canonical bundle hash、自身 schema/canonical/profile、四轴、G3 child/feedback actual-or-absent identity 的独立验证；旧 package/hash/receipt 不变，且 candidate identity 可独立重算。真实 G3 children 缺失时只能是 `terminal_deferred`。
- T2 退出门是新的 E0/G-I1A/E1/E2/UP2 identity receipts，且同候选 source/bundle hash、四轴、child/feedback/authority provenance 全部可复核；formal B00/B04 仍须在首次执行前另行冻结、串行执行和独立复核。
- 保留 UP0–UP6、R01–R10、现行迭代和历史证据边界；本决议不缩减父目标，不授物理/工程/搜索信用。接受记录见 [AD-30 R2 acceptance](../implementation/AD-30/acceptance_r2/acceptance.md)，证据见 [acceptance manifest](../implementation/AD-30/acceptance_r2/evidence_manifest.json)。

提案和只读证据记录见 [AD-30 proposal](../implementation/AD-30/proposal.md) 与 [AD-30 evidence manifest](../implementation/AD-30/evidence_manifest.json)。

<a id="ad-31"></a>

## 20. AD-31 G3 realization candidate-owned source-edit precursor（2026-09-15）

状态：`accepted_limited`；范围仅为 realization-only candidate-owned closed source body、固定 `replace_source_payload` 编辑操作、closed provenance/typed absence、双状态证据边界和有限工作单。不同 Luna 对 R3 revised proposal 已 `pass_limited`；Sol 接受本架构与排期范围，不接受实现、actual child、T0/T1 authority、provider、mesh、engineering、physical、search、B00/B04 或 R01–R10 信用。

AD-31 首单只冻结一个 realization source-edit vertical slice：新增 `src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl`，使用 closed typed source body；新增 `test/GenomeV5/G3/g3_realization_child_editability_v1_tests.jl` 与专属 implementation archive。source payload 必须同时携带 typed parent G3 declaration ref/hash 和 additive child contract identity；child key 固定为 `candidate_ref + parent_g3_declaration_hash + child_kind=:realization + child_id`。source schema、canonicalization/profile、applicability/profile 和 evidence-receipt provenance 必须使用 closed source record/ref，并将 `source_record_hash` 独立纳入 source identity；缺失值只可用 typed absence 表示。

编辑 API 只有完整原子 `replace_source_payload`，不允许动态 field path、wildcard、insert、delete 或通用 `rebind_source`。`source_content_hash`、`initial_state_hash`、`expected_prior_source_content_hash`、`expected_prior_state_hash` 和结果 `state_hash` 分属不同层次；source-record hash 不得自递归，source/state stale mismatch 必须分别 `fail_closed` 且保持旧状态不变。`contract_admission` 与 `physical_resolution` 独立记录；本地声明、hash、测试、runner、provider label 或 `bridge_ready` 不得晋升 physical status。

该 precursor 可与 AD-30 T0 并行准备，不能 import/depend T0，也不能重定义 T0 child authority；未来 T1 另行执行唯一 source-backed lossless mapping。control、binding、feedback child 均排除并另立工作单。旧 G3 V5、旧 bundle、`CandidateStatePackageV5`、shared entry、`default_operator_registry()`、旧 hash/receipt 与历史 evidence 只读。缺 provenance/authority 保持 `terminal_deferred`，candidate/ref/hash/contract/closure 冲突保持 `fail_closed`；任何实现收据仍只属 software contract scope。

接受记录见 [AD-31 acceptance](../implementation/AD-31/acceptance.md)、[AD-31 manifest](../implementation/AD-31/manifest.json)、[AD-31 status repair R2](../implementation/AD-31/status_repair_r2/report.md)、[local software precursor acceptance](../implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/software_precursor_acceptance.md) 和 [status sync R1](../implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/status_sync_r1/report.md)。本地 source/test slice 仅因 frozen-r4 的 65/65、PID 15468、exit 0 与 raw receipt 获得 `accepted_limited`；机器 work-order node 仍 `planned`/`proposal`/`accepted=false`/`review_pending`。frozen-r4 之后的并发 planning drift 不回溯归因给 R6 source/test slice。actual child、T0/T1/T2、provider、mesh、engineering、physical、search、B00、B04 与 R01–R10 均为 false。

<a id="ad-32"></a>

## 21. AD-32 G3 control candidate-owned source-edit precursor（2026-09-15）

状态：`accepted_limited`；范围包括 control-only candidate-owned closed typed source/edit 架构与有限工作单，以及经独立 postrun R3 `pass_limited` 复核的 local source/test software implementation slice。Sol 接受该 local slice 为 `accepted_limited`，但 machine work-order node 仍 `planned`/`proposal`/`accepted=false`/`review_pending`；不接受 actual control child、source-backed T1/T2、T0、工程或物理证据。

AD-32 是 AD-31 realization precursor 的 sibling，可与 T0 并行准备；唯一前置是 `UP2-01-G3-SOURCE-FEEDBACK-V1` 与本 AD-32。它不依赖 realization 或 T0，不导入或重定义 T0 authority，也不关闭 T1。未来实现的文件归属严格限定为 `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`、`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl` 和 `docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/`。

R7 合同冻结 candidate/parent/child identity、由 `payload.source_record` 派生的 `source_record_ref`、由 candidate 与 parent ref/hash 派生的唯一 parent binding、actual additive child contract ref/hash 及逐字段相等的 source payload ref；child grouped key `(candidate_ref, parent_g3_declaration_hash, child_kind, child_id)` 在 initial identity recipe 中只序列化一次。source record、immutable source payload/content、editable state、axes、initial state、operation history 和 current state 分层哈希；历史操作名 `replace_fault_source_payload` 仅表示编辑一个 existing fault 的 `mode`，不改 immutable source payload、source record、axes 或 identities。typed absence、`unknown`/`terminal_deferred` physical reason、全历史 duplicate/ordering/previous-state 链和失败时 canonical bytes 原样保持均为硬约束；dynamic field/insert/delete/rebind、伪造 ref/hash、非 mode 或多 fault edit 必须 fail closed。

旧 `ControlGenomeV5`、旧 package/registry、T0/T1/core planning、历史 hash/receipt 均只读。R9 frozen local receipt 为 PID `51564`、exit `0`、`167/167`，source/test SHA256 分别为 `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb` 与 `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289`；R8 的 `149 pass / 18 fail` helper bug 保留为历史失败证据。AD-32 不授 actual control、source-backed T1/T2、realization、binding、feedback、T0、provider、mesh、engineering、physical、search、B00/B04 或 R01–R10 信用；parent R01–R10 不缩减。接受记录见 [AD-32 acceptance](../implementation/AD-32/acceptance.md)、[AD-32 manifest](../implementation/AD-32/manifest.json)、[local software precursor acceptance](../implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/software_precursor_acceptance.md)、[status sync R2](../implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/status_sync_r2/report.md) 和 [R7 independent review](../implementation/AD-31/g3_control_editability_independent_review_r7/report.md)。

<a id="ad-33"></a>

## 22. AD-33 G1/G2 parent-baseline binding prerequisite and reviewed edit siblings（2026-09-15）

AD-33 is `accepted_limited` for the architecture, finite work-order boundary and local typed-absent source/test/fixture/static-QA software slice, after the different-Luna R5 architecture and independent postrun R2 `pass_limited` reviews. The only machine node created by this synchronization is `UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC`, which remains `planned`/`proposal`/`accepted=false`/`review_pending` with `claim_ceiling=contract_only`. The G1 mechanism/source-body and G2 geometry/metric-boundary edit precursors remain reviewed future sibling nodes; no G1/G2 edit sibling machine node is created.

The shared node depends only on accepted `UP1-01`, `UP1-02` and `UP1-03`. The G1/G2 V1 declaration source and archive paths are read-only inputs, not accepted dependencies. It is parallel to T0, AD-31 and AD-32 and does not unlock or complete T0, T1 or T2. Its exact future ownership is limited to `src/GenomeV5/Integration/VNextParentBaselineBindingV1.jl`, `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_tests.jl`, `test/GenomeV5/Integration/vnext_parent_baseline_binding_v1_fixture.json`, `test/GenomeV5/Integration/static_qa_vnext_parent_baseline_binding_v1.py`, and exactly three dedicated archive documents: `docs/implementation/UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC/README.md`, `manifest.json` and `acceptance.md`. There is no launcher.

The shared contract freezes `PresentParentBaselineBindingV1 | AbsentParentBaselineBindingV1` and `PresentChildKeyV1 | AbsentChildKeyV1`. A present record requires the actual source-backed parent ref, declaration hash, raw-source and semantic-body hashes, source locator and factory/declaration receipt. An absent record contains only requested candidate, requested public contract, layer, closed reason, absence domain and absence digest; it never contains or fabricates a parent ref, parent/declaration/baseline hash, source locator or factory receipt. Absent state is typed absent with `contract_admission=:terminal_deferred`; `replace_source_payload` is forbidden, returns `baseline_authority_absent`, and failure leaves prior canonical bytes/SHA and history unchanged.

The maximum local implementation before a real source-backed V1 instance/factory receipt exists is the typed-absent scaffold. Its frozen local evidence is Python static QA `38/38` under `D:\\Users\\Newman\\anaconda3\\python.exe` (SHA256 `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`, version `3.13.5`) and Julia focused R5 `52/52`, exit `0`, under Julia `1.10.5` (executable SHA256 `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`); R1–R4 failed receipts remain historical and stable cleanup is `20/20` kept with zero removed. Absent-to-present is a fresh source publication with fresh child/state/candidate identity review, never CAS promotion. Present G1/G2 child implementation and source publication remain blocked on the respective `UP2-01-G1-DIFFUSION-V1` or `UP2-01-G2-METRIC-BOUNDARY-V1` real declaration receipt plus fresh same-candidate identity review. AD-33 grants no present G1/G2 baseline/child, source publication, implementation beyond this local slice, actual child, UP1-04A-VNEXT-T0/T1/T2, UP2, provider, mesh, solver, engineering, physical, search, B00, B04 or R01–R10 credit. See [AD-33 acceptance](../implementation/AD-33/acceptance.md), [AD-33 manifest](../implementation/AD-33/manifest.json) and [status sync R2](../implementation/AD-33/status_sync_r2/report.md).

<a id="ad-34"></a>

## 23. AD-34 G3 binding/feedback architecture and authority recheck boundary（2026-09-15）

AD-34 is `accepted_limited` for the architecture and finite work-order
boundary after repair R4 and independent review R5. It freezes one
candidate-owned G3 binding editable sibling and no feedback child. The binding
machine node `UP1-04A-VNEXT-G3-BINDING-EDIT-PREC` remains
`planned`/`proposal`/`accepted=false`/`review_pending`, depends only on
`UP2-01-G3-SOURCE-FEEDBACK-V1`, and owns exactly six future files. Current
state is a typed-absent scaffold; link CAS and `PresentChildBindingV1` are
blocked until checked-present T0 authority recheck and same-candidate source
children exist.

The separate `UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC` node is accepted only
as a local typed-absent software scaffold under independent postrun R3
`pass_limited`; its machine state remains
`planned`/`proposal`/`accepted=false`/`review_pending`, it depends on
`UP1-04A-VNEXT-T0`, owns exactly seven files with no launcher, and is a T0
output authority gate before T1. Future T1 depends on both T0 and the recheck;
T0 itself is unchanged. R6 static QA recorded 20 checks and direct focused
Julia recorded 68/68; R1-R7, cleanup, and the foreign declaration candidate
repair remain append-only evidence. The recheck accepts only a fresh T0-owned
declaration authority record or typed absence and emits checked-present,
typed-absent, or fail-closed. It never synthesizes declaration
ref/hash/canonical bytes/source receipt fields from legacy G3 authority. Since
the current result is typed-absent only, T1 remains blocked.

The pairing contract requires exactly one upstream authority for each G1/G2
layer. Duplicate, missing, unknown layer, target layer/candidate/authority
mismatch, duplicate/ambiguous target, and legacy projection mismatch fail
closed with the fixed R4 errors. Multiple distinct target keys may share one
layer. Legacy six-field equality is only an internal consistency check and
never promotes authority; legacy `:actual` is always
`typed_absent`/`terminal_deferred` until the independent recheck supplies
source-backed declaration identity and receipt.

The binding immutable source owns `initial_links`; its editable body is an
exact canonical-byte copy, with independent source/content/child/initial/
operation/state hash layers and closed operation history. Before checked
present recheck output, all link CAS operations fail atomically and preserve
old bytes, history, and hashes. Feedback metadata remains parent G3/T0-owned;
runtime residual/loss/thermal/deformation values remain candidate-bound
evidence records. No feedback child or T0 adapter is added to the binding
scope.

The exact scopes, inputs, outputs, pairing errors, DAG, control refresh and
acceptance ceiling are recorded in [AD-34 acceptance](../implementation/AD-34/acceptance.md),
[status sync R1](../implementation/AD-34/status_sync_r1/report.md), the
[authority-recheck status sync R1](../implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/status_sync_r1/report.md),
and the [repair R4 proposal](../implementation/AD-34/g3_binding_feedback_audit/repair_r4/revised_proposal.md).
All actual binding/feedback/control/T0 authority/T1/T2/provider/mesh/
engineering/physical/search/B00/B04/R01–R10 credits remain false.

<a id="ad-36"></a>

## 25. AD-36 mandatory evidence sidecar scope amendment (2026-09-15)

AD-36 keeps `exact_file_count` limited to product/contract deliverables. Mandatory append-only implementation/test evidence sidecars—raw stdout/stderr, exit, PID/UTC, interpreter, input/output hashes, repair reports, cleanup inventory, independent reviews and status sync—must live under the task-owned `docs/implementation/<task-id>/archive/**` or named review/status subdirectories. They do not increase the product/contract count, cannot overwrite an earlier round, cannot escape the task-owned directory, and are protected from cleanup. Temporary launchers remain forbidden and tests use direct commands. The amendment applies to AD-34 binding6/recheck7 and future exact-scope work orders; it leaves the 39-task DAG and all physical/R credit boundaries unchanged. AD-36 is now `accepted_limited`/`accepted=true` for this sidecar contract only; no affected implementation or physical credit is granted.

<a id="ad-35"></a>

## 24. AD-35 task closeout and cleanup contract (2026-09-15)

状态：`accepted_limited`；范围仅为协作关账合同；`accepted=true`；`accepted_scope=collaboration_contract`，由 Sol/root 依据 independent_review_r4 `pass_limited` 裁决。AD-35 不创建新主线 task，不改变 UP0–UP6 DAG 或现有 39-task count，不授予 provider、mesh、工程、物理、搜索、B00、B04 或 R01–R10 信用。

每个分派子任务必须在收尾前完成实现与验证：实现任务执行其专属正向和负向测试，保存真实 raw/PID/exit/hash；纯架构、审计或文档任务执行适用的 JSON/link/diff/format/static validation，显式写 `code_tests=not_applicable`，不得伪造代码测试或物理证据。每个适用命令的 receipt 还必须有 command、cwd、PID 或 `in_process`、UTC start/end、stdout/stderr/combined raw 内容及 SHA256、exit code、input/output/artifact hashes。实现、验证和清理共用同一任务 ID；清理不能替代测试，测试不能替代独立复核。

关账前冻结 base/dirty/protected hashes，逐路径建立 cleanup inventory（path、owner、category、before/after existence、before/after SHA256、action、reason）并记录 `final_exact_owned_set`。删除/回退只允许作用于本任务创建且不属于冻结交付、测试、失败 evidence 或 accepted artifact 的 scratch/cache/debug/unrelated code；ownership 不确定则 `cleanup_deferred_ambiguous` 并保留。pre-existing dirty、他人文件、R1–R10 失败 raw receipts 与 accepted artifacts 永久保护；禁止 broad glob、全局清理、按扩展名批量删除和全局 revert。清理后由不同 Luna 独立复核，重计算仍串行，Sol 决定 `accepted` 或 `changes_requested`。

合同与本次 status sync 见 [AD-35 acceptance](../implementation/AD-35/acceptance.md)、[manifest](../implementation/AD-35/manifest.json) 和 [status sync R1](../implementation/AD-35/status_sync_r1/report.md)。AD-35 自身只产生文档合同验证，不关闭任何实现工单或父目标。
## AD-36–AD-38 and UP3–UP6 preparation status decision (2026-09-15)

AD-36 is accepted-limited for the mandatory evidence-sidecar scope contract. Exact file counts include only product/contract deliverables; append-only raw streams, receipts, hashes, repairs, cleanup inventories, reviews and status syncs are evidence-only sidecars and remain protected. A sidecar carrying product/source/test/fixture/static-QA/launcher payload is `scope_violation` and fails closed.

AD-37 is accepted-limited for the current G1/G2 present-baseline absence audit and the boundary of two future, independently dispatched publication work orders. No present G1/G2 publication, machine node or implementation is accepted. AD-38 is accepted-limited for a static compile/discretization gap audit and future finite work-order boundary. It remains blocked on checked-present same-candidate T0 authority and the T1/T2 identity chain; `PhysicsCompilerV5`, general EquationIR/WeakResidualIR/DiscreteResidual/SolverPlan execution, provider, mesh and physical evidence remain closed.

UP3–UP6 early-preparation packages are accepted-limited preparation/template records only. UP3 does not fix candidate hashes or run physics; UP4 keeps reference data and adapters independently archived and out of the final package; UP5 does not transfer evidence or prune candidates; UP6 keeps all provider, VVUQ, engineering, originality, replay, net-output and R01–R10 conclusions pending. None creates a machine node or changes the 39-task DAG. Provider, mesh, solver, search, engineering, physical, B00, B04, R01–R10 and L4 credits remain false.

The retained `task_manifest.json` field `environment_gate.task_count_unchanged=false` belongs to the AD-29 environment gate's comparison with its earlier 31-task baseline. It is not evidence of a current DAG mutation and is not rewritten in this repair. The current manifest hash, live count of 39 tasks and acyclic validator result establish `task_count_unchanged=true` for this synchronization; the link count is likewise only static plan evidence.

## AD-39–AD-42 and G3 binding synchronization decision (2026-09-15)

AD-39 and AD-41 are `accepted_limited` architecture/static audits. AD-40 is `accepted_limited` for the repository-design source-authority architecture and its seven finite, separately reviewable work-order contracts. AD-40 W2's repaired authoring outputs remain typed-absence, point-in-time excluded observations; they do not establish source authority, candidate identity or present publication. AD-42 is `accepted_limited` for the acyclic public-contract materialization boundary and W0→W2R1 preparation contract. W0 is explicitly parallel and prepare-only, and no W0/W2 machine node is created.

The G3 binding precursor is `accepted_limited` only for a local typed-absence software slice. The machine node remains planned/proposal/accepted=false/review_pending. Checked-present authority, actual G3 binding/feedback children, CAS promotion, T1/T2, provider, mesh, solver, engineering, physical and search execution remain closed. G1/G2 public refs and payload authority remain false; all R01–R10 and L4 credit remain false/zero. This decision does not alter the 39-task task_manifest or the ordered UP1→UP2→UP3→UP4→UP5→UP6 gates.

## AD-42–AD-48 architecture status decision (2026-09-15)

AD-42 W2R1 is accepted only as fresh canonical G1/G2 source authoring. AD-43 is accepted only as the general G1/G2 four-axis software contract with typed absences. AD-44 W3-A is repository-design provenance from untracked working-tree bytes, not committed source authority; W3-B remains blocked. AD-45 A's common `QualifiedRefV1/v5` is a temporary G1/G2 handle only. AD-46 requires a complete, independently reviewed G1/G2/G3 join before final identity materialization.

AD-47 W0 is an additive G3 axis contract with exact source-byte/hash closure. AD-47 W1 remains eight typed-absence source-provenance products and does not grant G3 source authority. AD-48 S1 supplies independent working-tree locators only. S2 factory identity probing is `in_progress`/`pending` until independent review and root decision; only an independently evidenced `AbsentG3FactoryIdentityV1` permits conditional F0, followed by fresh S2, S3, fresh W1 and W2. This preserves `T0 → authority recheck → T1 → T2 → aggregate → UP2 → UP3 → UP4 → UP5 → UP6`, adds no machine node, and keeps provider, mesh, solver, engineering, physical, search, R01–R10 and L4 false/zero. Documents, tests, agents and exits cannot substitute for physical evidence.

<a id="ad-50"></a>

## AD-50 core status synchronization boundary（2026-09-16）

Sol 裁决：AD48 F0、S2、S3 与 AD49 F0、S2、S3 均按各自独立复核和 root 记录同步为 `accepted_limited`，范围只包括软件能力和诚实的 typed absence。AD48 的 external trust root 仍缺失；AD49 S3 的 gate 为 `blocked_external_trust_root_and_source_closure`，四个 readiness 89–92 产品保持 `typed_absent`、`terminal_deferred`、`no_publish`，G2 mapping 保持 absent。Formal S3 在 root 记录前的 `review_pending`/`root_acceptance_pending` 历史状态保留在归档，不被回写成 present。

本裁决只允许 AD50 核心状态同步，不解锁 G2 mapping、W3B 或 AD46 identity materialization。AD44 W3B、UP1-04B、UP2-00、B00、B04 继续按既有合同 pending/blocked；T0/T1/T2、provider、mesh、solver、engineering、physical、search 和 R01–R10 均为 false，L4=0。不得把 root/independent review、文档、测试或 runner exit 当作物理或工程证据。本裁决不修改共同合同、`task_manifest.json` 或 UP0–UP6 DAG。

归档见 [AD49–AD50 synchronization report](../implementation/CORE-STATUS-SYNC-AD49-AD50/report.md)。
AD50 本身当前为 `implementation_status=completed_review_pending`、`independent_review_status=pending`、`root_acceptance_status=pending`、`decision=review_pending`；本段只记录状态同步实现，不构成 AD50 验收。

<a id="ad-56"></a>

## AD-56 Git-filter portable source locators (2026-09-16)

AD-56 修复 G1/G2/G3 source locator 在 Git 文本过滤和 CRLF checkout 下把干净工作树误判为篡改的问题。locator 的 `source_bytes`、`source_sha256` 和 `head_blob_sha256` 现在统一表示 canonical `HEAD:path` blob bytes；它们不表示平台 checkout 后的 raw working-file bytes。canonical repository content 与 platform checkout bytes 是两个有意分离的层次：raw 工作文件必须存在且可读，但合法的 LF/CRLF 表示差异不能单独造成失败。

工作区真实性仍由完整联合证据证明：repository root 与 Git top-level 相同，`HEAD` 与 locator 一致，目标存在于 HEAD tree，index 有唯一 stage-zero tracked entry，没有 assume-unchanged/skip-worktree 标志，目标路径 porcelain clean，并且安全参数数组调用 `git hash-object --path <repo-relative-path> <working-file>` 得到的 filtered blob OID 等于 `HEAD:path` blob OID。任何 dirty、filtered blob mismatch、HEAD mismatch、path relabel、index flag、canonical hash/length relabel 或缺失 raw 文件都 fail closed。该修复不降低任何 trust、candidate、final、provider、mesh、solver、physics 或 search 门。

AD-56 的 core.autocrlf=true 临时 Git fixture 证明 HEAD LF、checkout raw CRLF、filtered OID=HEAD 且 porcelain clean 时 G1/G2/G3 均可 present；随后有效内容修改均 fail closed。原 core.autocrlf=false fixture 与 adversarial controls 保留。该决策只修软件 provenance portability；source authority/trusted/candidate/final/provider/mesh/solver/physics/search/R01-R10 仍为 false，L4=0，AD55 F0/S2 仍需修复后 fresh rerun。task_manifest、31/534/39/acyclic 约束保持不变。
