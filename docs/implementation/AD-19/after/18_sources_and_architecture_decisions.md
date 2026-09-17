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
| UP1-04 integrated | 完整 ref 四字段、四轴、candidate binding 的逐字段相等性及 identity rebuild | wrong layer/version/ref fail-closed；provider gap 独立；没有执行/物理信用 |

<a id="ad-19"></a>

## 8. AD-19 V4→V5 migration and package join boundary（2026-09-14）

Sol 裁决：完整 V4→V5 的 lossless mapping 当前为 `none`。G1 只有在声明驱动、逐项源字段/AST/closure/gene/canonical 证据齐全时才允许条件迁移；G2、G3 缺少目标语义或权威字段时只能 `terminal_deferred`，结构错误必须 `fail_closed`。旧 evidence、旧 hash 和旧 candidate identity 不得作为新 ref 或迁移证明。

采用 additive 强类型 `CandidateStatePackageV5`、显式 staged migration adapter，以及同一 candidate 的三层 exact join。V4 package、Compiler、Campaign 和既有运行入口保持原义和只读边界。V5 package 必须绑定三个实际公共外层 `GenomeContractRef`、每层四轴、三个实际 V5 component hashes、公共 refs、candidate binding，以及 G3 realization/control/binding child refs 与 feedback；G3 feedback 只有在同一 candidate 的真实 G1/G2 外层 refs 逐字段 exact compare 后才可关闭 authority gap。G2 wrapper 必须同时绑定 `candidate_ref` 与真实 `g2_genome_hash`；G1 candidate URI 必须 exact 相等，禁止 suffix 或字符串相似兼容。

身份重建必须由三个实际 component hashes、三层公共 refs、四轴、G3 child/feedback 和 candidate binding 的 canonical 内容生成。缺 mapping、provider 或 cross-layer authority 是独立 `terminal_deferred` gap；结构不合法、错层、错版本、错 ref 或绑定冲突是 `fail_closed`。fresh V5 且没有 legacy 输入时不得伪造 `terminal_deferred` migration receipt。存在 legacy 输入时，每个 receipt 必须记录完整 before/after ref 与 hash、四轴、字段逐项映射、identity before/after、算法版本、mapping provenance、状态和原因；旧 evidence 不复用。正式 B00/B04 suite 在最终 schema 完成后、首次执行前另冻版本。本决议不授实现、provider、B00/B04、工程、物理或 R01–R10 信用。
