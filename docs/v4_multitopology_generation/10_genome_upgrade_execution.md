# 三 Genome 覆盖升级执行总纲（拟议）

> 本文件是规划文档，不是实现报告。所有带有“拟议”标记的 schema、profile、migration、compiler、receipt 和 gate 都需要后续工作单执行后才可成立。本文不新建任务 ID；具体文件归属、执行顺序和工作单由主线程的 `16_execution_work_orders.md` 与 `task_manifest.json` 定义。

> 统一版本声明：本文中的 V2/V5、profile、migration receipt、compiler 和 gate 均为拟议；UP0–UP2 的合同、输入输出、阈值和身份规则必须先冻结，再进入 UP3–UP6。四个版本轴分别是 payload schema version、canonicalization/hash profile version、grammar/capability applicability profile version、execution/evidence receipt version；它们不能互相替代。V1/V4 历史哈希、执行 receipt 和证据保持不变。

## 1. 目的和现状边界

本次升级把原先受限的三 Genome 覆盖扩展为一条可执行链：机制程序（G1）提出可组合、可审计的方程和算子；场—几何（G2）把抽象区域、接口、外部域和拓扑物化为连续场及离散对象；实现—控制（G3）用受资源、材料、热结构、制造和故障约束的网络近似目标源并闭环控制。三者共同服务于完整装置候选和 R01–R10 独立验收。

源码核对得到的基线如下：

|层|当前可复用能力|当前边界|
|---|---|---|
|G1|`MechanismGenomePayloadV1`、`TypedASTProgramV1`、`AtomicMIMOHyperedgeV1`、精确 occurrence ownership、observable/hole closure；历史 v68 残差编译参考|V1 admission 有限上限；operator registry 和 compiler 未泛化为开放物理 Grammar，v68 不是当前通用执行器|
|G2|`FieldGeometryGenomeV4`、`SpatialSupportGeneV1`、chart/transition、`PhaseFieldSetGeneV1`、`TypedFieldProgramGeneV1`、field evaluation、显式 mesh/quad artifacts|空间 runtime 仍是特定静态两区域 Q1 (B_R,B_\phi,B_Z,p) 实例；一般区域/接口/外部域/拓扑演化尚未闭合|
|G3|`RealizationControlGenomeV4` 的双 typed graph、独立 seeds、不可变/canonical payload；engineering/control/fault contracts 和 provider admission|现有 realization/control 仍是窄模板或 overlay；任意 source 的硬件逆向、供能—热—结构反馈和独立故障闭环未完成|

因此，已有 typed AST/hypergraph 是三个 Genome 的公共结构核，但不是“任意 Genome 已可执行”的证明。当前局部执行、接口测试、固定两区域收敛或文档生成都不能把 `credible0` 改为非零；历史失败、`unknown`、`unsupported`、`physical_fail`、`numerical_fail`、`not_executed` 和 `deferred` 必须继续分账。

## 2. 共同版本、profile 和迁移规则（拟议）

每个 Genome 输入必须成为可解析的版本化合同引用：

```text
GenomeContractRef (现有结构，继续复用)
├─ uri
├─ version
├─ schema_hash
├─ canonicalization_hash
└─ compatibility_profile
```

拟议的三层 profile 为 `G1SchemaProfileV2`、`G2SchemaProfileV2`、`G3SchemaProfileV2`；它们分别引用 `GrammarProfileV2`、`SpatialGrammarProfileV2`、`RealizationControlGrammarProfileV2`（名称均为拟议）。profile 必须把适用域、能力轴、预算、导数/离散策略、资源和失败状态写入 canonical payload。新增 operator、拓扑事件、材料数据集、source backend 或控制 primitive 都要有自己的版本和 hash，并通过 candidate-owned/additive profile 接入；不能静默改变旧 registry、旧 schema 或旧 canonicalization。

每一条迁移都产生 `G1MigrationReceiptV2`、`G2MigrationReceiptV2` 或 `G3MigrationReceiptV2`（拟议），至少含：source/target URI 与 version、两侧 schema/canonicalization hash、字段映射、保留字段 hash、无法表示的语义、迁移程序版本、结果状态和人工/独立审查引用。无法证明语义等价时必须记录具体 `match_reason`，并将迁移分支置为 `unknown` 或 `terminal_deferred`；`unsupported` 只能由最终 authority 依据证据给出。V1/V4 历史字节、candidate hash、执行 receipt 和证据文件保持原值；新 identity 不能冒充旧 identity。

字段数量、AST/program 节点数、场系数数、网格 DOF、网络节点/边、solver unknown 和控制状态数必须在 manifest 中分列。G1 数量是机制程序复杂度；G2 mesh DOF 是离散化产物；G3 网络和控制状态数是实现/闭环容量。它们不能互相代替，也不能用增加 DOF、basis 或控制器参数为任意功率或目标场提供免费能力。

## 3. 语义归属和接口

|语义|唯一归属|跨层接口|
|---|---|---|
|方程、状态、守恒、operator effect、导数、适用域|G1|typed state/port、residual row、ledger occurrence、capability signature|
|区域、边界、接口、空间拓扑、连续场、网格、外部域|G2|field/source target、oriented trace、mesh/DOF map、spatial provider receipt|
|源硬件、材料、热结构、供能、制造、传感器、估计器、策略、执行器、保护|G3|functional port、resource ledger、actuator dynamics、sensor trace、fault/protection obligation|

G1 不拥有 G2 的区域语义；G2 不把线圈、组件或控制策略写进场 Genome；G3 不修改 G1 方程或 G2 拓扑。G2 的 target/source 只是跨层需求和空间约束；G3 是否能由有限 source basis、资源网络和控制约束实现，必须到 UP4 通过逆向、回代和工程证据后才能声称。任何接口都要绑定 candidate、三 Genome contract refs、profile/schema hash、scenario、provider、uncertainty 和 independence group。

## 4. 固定升级路线

### UP0：基线合同

输入是当前三 Genome payload/graph、contract registry、canonical bytes、历史 artifacts 和失败账本。输出是三份基线清单（拟议）以及共同的 evidence/status vocabulary。

执行步骤：

1. 对 V1/V4 payload、schema hash、canonicalization hash、contract ref、seed、graph、payload 和现有 receipts 做只读清点。
2. 分别记录 G1 occurrence/constraint closure、G2 abstract→geometry→mesh 链、G3 port/resource/control/fault 绑定。
3. 标出当前实际能运行的 structural/screen slice、特定 provider 的适用域和所有未闭合项。
4. 为受保护历史文件保留原 hash；任何新审计只产生新报告。

正向测试：同一输入重放获得同一 canonical bytes 和 hash；三 Genome 的引用、graph 节点、root、参数、资源、接口和故障 obligation 成功闭合。反向测试：改 hash/profile、删除 occurrence、混入 legacy edge、复用外来 receipt、将未绑定 capability 当 wildcard 均被拒绝或显式标记 gap。

退出门：旧 hash/证据可重放，当前边界已写入 manifest，`credible0` 未被改动。失败处理是写入具体 `match_reason` 与 `unknown`/`deferred`/`terminal_deferred`，不扩张旧构造器，不删除失败证据；最终 authority 才能在证据充分时写入 `unsupported`。

### UP1：三 Genome 合同和最小可执行组件

输入是 UP0 清单、三份拟议 schema/profile 和每层一个最小 typed component。输出是版本化 admission/migration 合同、最小跨层编译计划和 candidate-bound receipt（拟议）。

执行步骤：先接入 schema/profile/hash 校验，再接入 G1 类型/单位/效应/导数审计、G2 region/interface/chart/mesh 计划、G3 port/resource/sensor/actuator/fault 计划；历史 v68 残差编译仅作为边界参考，field evaluation 和 ECF admission 也只能在各自适用范围内适配。当前 typed AST/opcode registry 的注册不等于任意程序可执行，也不等于存在 generic runtime compiler。成熟数值库（残差、网格、求解器、VVUQ、逆问题）按能力复用，不重写整个数值库；必要的 adapter 不得把 backend-specific 类型泄漏到 Genome schema。

正向测试：最小 G1 governing/additive/constraint 程序、最小 G2 双区域定向接口与 mesh、最小 G3 source/resource/sensor/actuator 闭环都能生成确定性计划，并带完整 hash 绑定。反向测试：单位/端口/方向/资源/故障不匹配、越界、缺 provider、无导数或无 mesh 能力均 fail closed。

退出门：只能证明合同、编译计划和最小执行组件成立；无真实物理/工程 provider 时状态不超过 `screen_only`/`deferred`。失败处理必须区分 `program_exception`、`unknown`、`numerical_fail` 和 `not_executed`；`unknown` 表示尚未证明。能力路由只记录结构化 `match_reason`（如 `no_provider`、`domain_mismatch`、`capability_unproven`），不把中间匹配结果冒充最终 authority 状态；只有最终 authority 依据证据作出结论时，才允许使用 `unsupported` 等终态分类。

### UP2：物理编译、空间离散和耦合层

输入是通过 UP1 的三 Genome、G1 residual/ledger、G2 continuous field/mesh/接口、G3 source/material/resource/control，以及完整 capability signatures。输出是共享 residual、space/discretization mapping、source/resource/thermal/structural/control coupling 和 VVUQ input（拟议）。

执行步骤：

1. G1：把 governing/additive/constraint 编译成统一 residual，审计状态覆盖、单位、时间、导数、Jacobian slot、flux pair 和 closure。
2. G2：将抽象拓扑物化为区域/接口/外部域，生成连续场和网格/quad/DOF mapping，记录 geometry/mesh/evaluation hash。
3. G3：将 source basis、actuator dynamics、资源账本、材料热结构项、sensor/estimator/control 状态接入相同耦合链。
4. 对共享残差做制造解、守恒/接口、网格/基函数、资源账本和不确定度检查。

正向测试：制造解恢复、全局和局部守恒、接口 transfer、网格/基函数收敛、source 回代误差、功率/能量闭合、热结构反馈和有限带宽控制均可重放。反向测试：求解后再拼 reaction/radiation/actuator、没有外部域/返回路径、仅固定两区域、source mismatch 由控制分数补偿，均不得称为 coupled pass。

退出门：所有声明贡献在同一 candidate-bound residual/assembly 中，有明确 provider、scenario、grid、uncertainty、independence 和 exit code。失败处理保存完整输入、残差、迭代历史和 artifacts；低保真不收敛不自动构成永久无解证明。

### UP3：合法组合自动执行

输入是通过 UP2 的 G1/G2/G3 prefix、各 profile 的合法组合规则和 capability signatures。输出是可重放的组合清单、compile/geometry/mesh/resource/control manifests、failure frontier 和新 candidate identities（拟议）。

执行步骤：使用 canonical prefix DAG，而不是一次枚举完整笛卡尔积；按完整 capability axis 路由 provider；每次 G1 方程、G2 拓扑/外部域或 G3 source/材料/控制变化都重建 candidate identity，并重新验证所有受影响 upstream receipts。

正向测试：同一 prefix 的顺序变化经 canonicalization 后 identity 一致；结构、profile、topology、mesh、network、material 或 policy 任一变化都会产生新 hash。反向测试：按 family/name/candidate ID 猜 provider、空 capability 轴当 wildcard、复用 foreign receipt、只换 basis 冒充拓扑变化均拒绝。

退出门：自动执行只授予组合和执行收据，不授予物理、工程、控制或安全 pass。失败处理：先记录 capability match 的具体 `match_reason`（如 `no_provider`、`domain_mismatch`、`capability_unproven`），再以 `terminal_deferred` 作为该分支终态；只有最终 authority 才能依据证据给出 `unsupported` 等终态分类。低保真失败进入 failure frontier/dormant pool；不删除或覆盖失败分支。

### UP4：逆向源硬件 realization 与供能热结构反馈

输入是 UP3 的连续目标场/源、G2 区域/接口/外部域和边界、G3 source basis/材料/网络/制造/控制/保护合同。输出是可制造候选、source 回代误差、功率/能量账本、热结构反馈、sensor/actuator/fault receipts（拟议）。

执行步骤：求解有限 source basis 的逆问题；检查 rank/condition、目标场回代、空间 support、带宽、幅值、ramp/duty、供能/冷却、clearance、曲率、材料 operating domain、制造/维护路径；将温度、变形、损伤和资源状态反馈到 field/source/control residual；对规定故障执行保护和恢复场景。

正向测试：多起点逆解和 held-out 场预测、source capability 误差、功率/能量闭合、热结构稳定、材料属性域、制造约束、观测性、保护 deadline 和 fault recovery 均由独立 provider 重放。反向测试：欠秩 source basis、无返回路径/冷却/电源、材料超域、无实体传感器、瞬时无限 actuator 或控制评分掩盖 source mismatch 均进入相应失败账本。若 source 自由度 rank 缺失，必须先按声明的可识别组合、观测空间和误差适用域分类；只有在该适用域内已证明物理不可行时才记 `physical_fail`，否则保留为 `unknown` 并进入 `terminal_deferred`。

退出门：仅完整 source realization、资源、热结构、制造、控制和故障证据可进入整装候选；局部 pass 不提升 whole-device status。失败处理区分 `physical_fail`、`numerical_fail`、`unknown`、`deferred` 和 `not_executed`，并保留 match reason；`unsupported` 只由最终 authority 依据证据签发。

### UP5：条件 e-graph 与扩大演化搜索

输入是 UP4 前沿、三 Genome profile、带 checker hash 的 conditional rewrite、QD/MCTS lineage、mesh/basis/engineering budgets。输出是可重放 rewrite trace、candidate lineage、分层 frontier 和新的合法 prefixes（拟议）。

执行步骤：只使用保类型、保单位、保守恒 ownership、保接口方向、保资源/故障约束的条件重写；交替结构编辑、拓扑/网络变化与连续优化；用多保真调度和 capability routing 控制成本；每个新分支都保存 parent/new hash 和上游 receipts。AI、LLM、GFlowNet、MCTS、surrogate 只能提议和排序预算，不能产生 evidence、改变硬门或发出终态分类。

正向测试：条件满足时 rewrite 可重放且保持三 Genome contract；同一等价类的 canonical identity 稳定；扩大搜索不丢失失败 frontier。反向测试：缺 condition、过时 manifest、跨单位/账户的 rewrite、直接制造 Betti 数或功率、删除故障来提高分数、用 surrogate 当物理证据均拒绝。

退出门：搜索只覆盖声明 profile 的可达空间，不能宣称任意等离子体或任意装置已覆盖；未有独立物理/工程证据不得晋级。失败处理：checker 不确定为 `unknown`，预算/能力不足为 `deferred`，仅在可 replay 的无解证明下才允许永久 prune。

### UP6：整装 R01–R10 独立验收

输入是最终三 Genome candidate、全链路 manifests/receipts、独立 physics/engineering/control providers、VVUQ、证据 authority、replay 环境和规定的 R01–R10 清单。输出是整装验收包、逐要求 evidence ledger、独立重放结果和最终状态（拟议）。

执行步骤：核对真实 candidate identity 和三 Genome refs；重跑机制/场/几何/网格/源硬件/供能/热结构/控制/故障链；执行多起点逆向、held-out、跨分辨率/基函数、独立 provider 和不确定度；逐项审查 R01–R10 的证据源、适用域、独立组、退出码和 claim ceiling。

正向测试：至少一个候选通过其适用的物理、工程、控制、安全、VVUQ、证据 authority 和独立 replay 硬门，且所有 receipts candidate-bound。反向测试：固定模板、局部 screen、合成数据、单次收敛、单一 basis、单一 provider、文档/接口测试或控制 overlay 均不得满足整装验收。

退出门：R01–R10 每一项都必须有逐项关账记录、适用域、独立证据、依赖和终态；声称“不适用”也必须由该项的显式义务与 proof 关闭，不能忽略整个 R 项。只有 R01–R10 全部关账且没有更高层未闭合依赖，才可更新 parent goal；否则继续保持未完成，`credible0` 不上调。失败处理按 `scientific fail`、`program exception`、`human interruption`、`not_executed`、`unknown`、`physical_fail`、`numerical_fail`、`deferred` 分开报告；`unsupported` 只有在最终 authority 有证据支持时才可使用。

## 5. 复用算法和最小实现策略（拟议）

升级工作的最小实现策略是增加版本化适配层、profile 和 receipts，复用已有 typed AST/hypergraph、历史 v68 残差编译参考（非当前通用执行器）、G2 field evaluation/mesh pipeline、现有 spatial/provider contracts、工程/控制/fault contracts，并把 FreeGS、DESC、Gridap、Trixi.jl、Gkeyll、FUSE 或逆问题后端仅列为候选依赖/适配目标。候选路径、包名或外部文献不表示已经集成；只有 versioned provider manifest、能力匹配、输入输出合同、可执行命令和 candidate-bound receipt 齐全后才可记为 provider。FUSE 等框架也不能因此被当作通用物理求解器。后端只在其声明的 geometry/symmetry/topology/physics/applicability 范围内调用；缺少能力时 fail closed。不会因接口扩展而修改旧 `default_operator_registry()`、旧 V1/V4 canonical bytes、历史 hash 或旧失败证据。

实现顺序必须遵守 UP0→UP1→UP2→UP3→UP4→UP5→UP6；昂贵 Julia/DESC/多物理执行按工作单串行或受控批次进行，并等待终态 artifacts、审计、资源和重复性结果。局部构造器、单元测试、runner exit 0 或报告生成都只能证明软件步骤，不能替代物理、工程、独立验证或 R01–R10 证据。

## 6. 未决点与停止条件

以下项目在对应执行前保持未决：开放 Grammar 的 operator ontology 和适用域、一般拓扑事件的物理模型、抽象拓扑到可解析网格的统一义务、外部域/返回路径、source inverse 的可辨识性、材料数据域、热结构反馈、制造公差、故障独立电源和 whole-device evidence authority。任何一个硬门缺失都应停在具体 `match_reason` 与 `unknown`/`deferred`/`terminal_deferred`，不能通过缩小任务定义、删除故障或改写历史哈希关闭目标；`unsupported` 保留给最终 authority 的有证据分类。
