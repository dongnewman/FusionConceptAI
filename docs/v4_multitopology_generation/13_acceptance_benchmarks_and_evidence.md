# v4 多拓扑生成：验收基准、证据合同与当前基线

> 文档性质：下一阶段可执行的知识与验收合同，不是物理源代码实现。
>
> 编制时间：2026-09-14（Asia/Shanghai）。当前事实截止：`runs/goal_recovery_20260913_012528_cst/task_queue.json` 的 `updated_at=2026-09-13T16:39:03+08:00`。
>
> 工作单归属：沿用主线程 `16_execution_work_orders.md` / `task_manifest.json`。本文不新建工作单、不改变工作单编号，也不把本文件的完成计入 R01–R10。

## 1. 适用范围与当前证据边界

本文把 UP0–UP6 变成可以执行、复放、审计和拒绝的验收合同。它继承本目录 [00_normative_contracts_and_state_model.md](00_normative_contracts_and_state_model.md) 与 [09_evidence_authority_campaign_and_v4_roadmap.md](09_evidence_authority_campaign_and_v4_roadmap.md) 的 authority、哈希、状态和 claim ceiling 规则。三种 Genome 的语义仍由 G1、G2、G3 各自合同拥有；本文只规定跨 Genome 的验收接口。

当前仓库事实：`HEAD=4b69f55f7f80240147a65a22809dc1207824dde2`（提交信息为 `Record terminal W23 package regression`），工作树有与空间链、测试清单、恢复队列、实现合同及大量 `runs/` 相关的既有未提交/未跟踪内容。任何实施者必须先记录本次执行的 `source_commit`、`dirty_source_hashes` 和工作树状态，不得把当前脏树误报为干净发布版。

`docs/reports/goal_recovery_20260913/goal_acceptance_ledger.json` 是恢复审计快照，记录的 `head=c9ee99035bc04908bfc0df1e3b60d8c86033bcfb` 早于当前 HEAD；它可作历史审计输入，不能覆盖最新队列事实。真实的 `goal.json` 位于 `runs/goal_recovery_20260913_012528_cst/goal.json`（SHA-256 `96D38AE3504F3BC71ED89013D9C32A9EEB9FFF45BE9BD65FDD5A8821489EB9AF`），其 `baseline_commit=c9ee990`、`latest_verified_commit=a173cec`、`platform_ready=false`、`discovery_goal_achieved=false`、`credible_candidate_count=0`，并保留完整 objective。`docs/reports/goal_recovery_20260913/goal.json` 不存在；manifest 应以 runs 下的 live goal 及其哈希为目标输入。下文 R01–R10 与 live goal 的父目标一致。

本基线的可信完整装置候选数为 **0**。`runner_exit=0` 只说明程序入口完成并写出结果；它不说明物理求解收敛、边界闭合、独立验证、工程合格或正净输出。任何报告必须同时给出入口退出码、各 solver/provider 退出码、scientific status、artifact 复核结果和 claim ceiling。

### 1.1 W22–W24 的最新可用事实

以下事实来自恢复队列（最新更新时间如上）和相应 `result.json`/中断记录；旧版文档中的 run 描述不自动升级。

| 工作项 | 当前事实 | 可计入的范围 | 明确不能计入 |
|---|---|---|---|
| W22 | candidate-bound DESC replay 请求与新鲜 DESC-v0.17.3 Python 重放已执行；focused `27/27`、负例 `10/10`、相邻 candidate `28/28`，完整入口退出 0。三次迭代 force/lsq-exact 的 optimizer `success=false`，有限残差 `L2=0.11682848292227506`、`max=0.012152898080190622`。 | 输入身份、请求哈希、provider 边界和“未收敛”诊断。 | RuntimeV4 provider admission、独立空间比较、物理验证；不能把有限残差称为平衡成功。 |
| W23 | `w23_algebraic_generation_r4/result.json`：3 个 candidate、2 个后代、3 个收敛的无量纲 0D screen，`process_exit_code=0`，checkpoint resume 已验证，3 个 exact capability obligations 仍 deferred。`R08_accepted=false`、`R01_to_R10_accepted=false`、`credible_device_count=0`，claim ceiling 为 `screen_only`。 | G1 typed proposal→candidate→0D screen→归档的有限纵切片。 | G2/G3 搜索、空间求解、物理验证、整装装置和 R08 关闭。 |
| W24 parent | `w24_spatial_parent_r1/result.json`：入口执行完成，`spatial_execution_minimum_reached=true`，`credible_device_count=0`，`p5_ready=false`，physical validation `unsupported`。四个物理 case 均 `iteration_limit`、solver exit 4；whole 状态 `deferred`。 | 候选绑定、G2 几何编辑、空间/工程屏幕的执行和失败传播。 | 收敛物理、净输出、工程合格或 whole-device credibility。 |
| W24 child | child 有独立 candidate/provider 身份；physics 四 case 均 `fail/exit=4/iteration_limit`，claim ceiling `screen_only`；engineering 已执行但因 invalid upstream `status=fail`、`engineering_qualified=false`、exit 0。 | 父子 identity 隔离、G2 单系数变化、失败分类所需的负例。 | 一次几何扰动不是原创性、开放搜索、独立验证或可信候选。 |
| W24 中断 | `w24_child_interruption.json` 记录原 PID 消失、verification artifact 尚不存在，已完成 upstream/physics/engineering checkpoint；分类是 `execution_interruption_not_scientific_terminal`。随后以 `--resume` 启动同 run checkpoint 校验，但在主线合并前仍需重新取得 terminal verification 与 paired audit。 | 中断/恢复协议的执行状态。 | 中断记录不能替代终局 evidence；没有 verification artifact 就是 `human_interruption` 或 `unknown`，不是 pass。 |
| N1 refined MMS | 三个分辨率均 solver exit 0，但观测阶包含 `-6.157952975473273`；该结果明确为 `numerical_only=true`、physical validation `unsupported`。 | 制造解的执行与网格一致性负例。 | 收敛阶通过、真实物理有效性或空间模型闭合。 |

## 2. 统一状态、失败和证据纪律

每个 benchmark、候选和 stage 必须保留至少这些独立字段：`applicability`、`provider_match`、`resolution`、`execution_classification`、`numerical_status`、`physical_status`、`lifecycle`、`claim_ceiling`。不得用一个 `status=fail/pass` 压扁不同原因。

执行类分类包括 `program_exception`、`human_interruption`、`not_executed`、`unknown`；`process_exception` 只作为历史原生记录的兼容别名，新的执行器必须归一化为 `program_exception` 或更具体的执行分类。数值类包括 `numerical_fail`（例如 solver exit 4/iteration limit、网格阶不成立、双代码差异超门）；物理类包括 `physical_fail`（适用 provider 成功计算且违反冻结硬门）。provider/能力缺口必须拆成 `provider_match=no_match|ambiguous|out_of_domain|invalid_signature` 与 `resolution=terminal_deferred`；`unsupported` 只能保留历史原生输出，不能作为新的中间终局分类。`not_applicable` 必须有任务和组件级证明。`scientific_fail` 可作为报告层汇总词，但必须展开到上述具体分类。

规则如下：

1. 入口 `exit=0` 只记 `process_completed`；只有 solver/provider 的科学退出和硬门观测才能改变 scientific status。
2. 入口异常、进程消失、人工停止、缺失 terminal artifact 不得写成 numerical 或 physical pass。
3. provider 成功执行但 candidate 上游无效时，工程结果记 `resolution=terminal_deferred` 并保留 dependency reason，不能把工程失败扩大成物理不可能；新的中间结果不得写 `unsupported`。
4. 数值不收敛与物理硬门违反分开记账；同一次运行可同时产生数值诊断和未决物理证据，但不能互相替代。
5. 一个失败 candidate 只能进入 candidate-local failure frontier、dormant 或待恢复队列；不能由有限失败自动删除整个 grammar、Genome 类型或拓扑族。只有 proof authority 对带完整证明的恒真不合法结构发出永久剪枝证书。
6. `predicted_outcomes`、代理分数、搜索收益、独特哈希和 queue 状态永远不是 EvidenceEnvelope，也不能晋升 terminal disposition。
7. 没有实际数据、适用 provider 或适用性证明时，必须记录 `applicability=required`（在取得不适用证明前保留义务）、`physical_status=unknown`、`resolution=terminal_deferred`，并把 scope assumption 写成未决输入；不能制造合法的 `not_applicable`，也不能生成通过结论。

每一份正式 evidence 至少包含：

```text
benchmark_id, requirement_id, candidate_hash, mission_hash, scenario_hash,
source_commit, dirty_source_hashes, data_sources, calibration_split,
validation_split, independence_groups, commands, process_exit_code,
provider_manifest_hash, solver_input_hash, execution_classification,
scientific_status, metrics_with_units, uncertainty_or_null, artifacts,
checker_version, scope, claim_ceiling, accepted_by, remaining_gaps
```

artifact 必须内容寻址、不可变并可由独立 checker 重新读取。未来新 run 写入新的 `runs/goal_recovery_<timestamp>/` 或主线程 manifest 指定的目录；不得覆盖历史 run、恢复 ledger 或旧 evidence。

## 3. UP0–UP6 阶段合同

阶段是依赖顺序，不是把局部测试数量相加的“完成百分比”。每阶段只有在其退出门和上游 evidence 都满足时才能晋升。

| 阶段 | 必须冻结的输入与执行内容 | 退出门（初始建议，需由 Sol 预注册技术协议） | 当前状态与下一步 |
|---|---|---|---|
| **UP0 基线合同** | 三 Genome contract ref/version/schema hash/canonicalization hash；mission、grammar、bounds、scenario；`CandidateStatePackageV4`、分层 hash、状态轴、authority；标签擦除和节点/区域/接口置换样例。 | 同一 bundle 在两个独立进程产生相同 canonical package/hash；display/family/name/benchmark 标签擦除后路由、hash、判定完全相同；中间模块不能发 terminal disposition；B00 全通过。 | P0 架构和类型已有局部实现，但本次父目标的统一 acceptance 与独立 replay 未关闭；由 UP0-01 刷新基线、UP0-02 冻结合同与协议。 |
| **UP1 G1/G2/G3 合同 + 可执行组件** | G1 `TypedASTProgramV1`/`TypedOperatorHypergraphV1`/`AtomicMIMOHyperedgeV1`；G2 typed coordinate/metric/boundary program；G3 realization/control、故障和供能接口；operator registry、units、conservation accounts、capability signature；每个可执行组件的 input/output schema。 | 每一类合法/非法输入都有确定的 type/unit/conservation/closure diagnosis；缺字段不靠 family 默认值补齐；B04 及组件对应的 B01/B05/B06 检查通过；provider gap 为 `terminal_deferred`。条件 egraph 的 B09 留在 UP5，不作为 UP1 前置退出门。 | W23 只证明 G1 0D screen；W24 证明一个 G2 edit screen；G3 与整机合同仍不完整。 |
| **UP2 编译离散耦合** | 从完整 candidate 编译区域、状态、接口、边界、源项、时间语义和离散空间；显式 interface flux/traction/current；source-to-spatial mapping；`SolverInputV4`、grid/basis/quadrature manifest。 | B01 MMS、B02 守恒/网格阶、B05 topology transfer、B06 boundary truncation 通过；每个 solver input 有唯一 hash；接口守恒和外部边界截断可独立复算。 | 当前空间链四 case 都在 iteration limit；N1 的一阶结果含负阶，不能进入 UP3。 |
| **UP3 合法组合自动执行** | 按 frozen manifest 从 G1/G2/G3 typed modules 生成有限的预注册合法组合和 held-out 组合；同一通用入口自动生成耦合方程/离散输入并真实求解，回写 evidence/archive；保留失败候选和可恢复 queue。 | 每个预注册合法组合及 held-out 组合均实际生成 candidate-bound coupled equations 并执行；非法组合不进入 solver；耦合回传拆除、边界/守恒破坏等负控制可识别；provider 缺口保持 `terminal_deferred`；乱序 merge/replay 一致。中等规模 campaign 与 B10 capability increment 留在 UP5。 | 当前 W23 是 3 个 G1 screen，W24 是一对 G2 parent/child，尚无 G1/G2/G3 组合闭环。 |
| **UP4 源硬件逆设计与物理反馈** | 有来源和单位可追溯的参考装置；隐藏参数/边界/线圈电流 inverse；独立 held-out observations；正向空间物理→工程供能、热、结构、控制和故障回传；B07、B08。 | 多初值、噪声/缺测、留出组合均通过；source→geometry→physics→engineering→feedback 的 identity/hash 全链；供能热结构闭环、故障场景和不确定性均有适用证据。 | W03/W09–W21 主要是来源绑定、边界/内部基重建和屏幕证据；W22 optimizer 未收敛，反解和工程闭环未达门。 |
| **UP5 条件 egraph 与广搜索** | `ConditionalRewriteSetV1`、`WholeProgramConditionalRewriteV1`、`DerivedConditionalEGraphV1`、条件/单位/守恒/适用性 proof；MCTS/Deep-QD/GFlowNet 或其他 emitter 仅产生 proposal；multi-emitter、failure frontier、OOD/heldout archive。 | B09 逐 rewrite 独立 replay；规则顺序与预算在配置中冻结，同配置重放确定；只有饱和至同一等价闭包且规范化确定时才比较集合；每个 rewrite 的条件成立才可合并 e-class；B10 paired baseline/capability increment 显著且不靠事后调门；proposal 与 evidence 权限隔离。 | 条件 egraph 核心类型和历史 focused tests 存在，但当前 W23 仍是 bounded G1 screen，未证明 G2/G3 广搜索或物理收益。 |
| **UP6 整装 R01–R10** | candidate-bound whole-device solve；时间周期、启动停机、供能回流、控制故障、正净输出；数值 VVUQ、独立 validation/UQ、原创性审查、最终 authority 与 fresh replay。 | R01–R10 所有 applicable required obligations 均有独立、可追溯、范围一致证据；至少一个新候选达到声明的 L4 scope；`FinalWholeDeviceAuthorityV4` 才能发 `credible_within_scope`。 | 当前 `credible_device_count=0`、`p5_ready=false`，全阶段仍未完成。 |

### 3.1 类型名与计划类型名

现有源码中可直接复用或继续审计的类型包括 `CandidateStatePackageV4`、`CompiledCandidatePrefixV4`、`TypedASTProgramV1`、`TypedOperatorHypergraphV1`、`AtomicMIMOHyperedgeV1`、`ConditionalEGraphBudgetV1`、`ConditionalRewriteSetV1`、`WholeProgramConditionalRewriteV1`、`DerivedConditionalEGraphV1`、`AlgebraicResidualPlanV4`、`AlgebraicSliceReportV4`、`ProviderManifestV4`、`CapabilitySignatureV4`、`SolverInputV4`、`EvidenceEnvelopeV4`、`CapabilityArchiveV4`、`SpatialMultiRegionDeclarationV4`、`FinalWholeDeviceAuthorityV4`。这些名字表示现有接口或合同，不表示对应的最终物理能力已经完成。

计划新增或需在主线程 manifest 中冻结的类型名，必须在 UP0-02 注册独立的命名空间、schema 版本轴、迁移关系和兼容性；运行时合同类型可采用 `DiscreteCoupledSolverInputV4`、`HeldOutCombinationSplitV4`、`SourceInverseProblemV4`、`SourceInverseEvidenceV4`、`EngineeringClosureLedgerV4`、`ConditionalRewriteProofV4`、`SearchCapabilityDeltaV4`、`IndependentReplayReceiptV4`、`WholeDeviceEnergyLedgerV4` 等名字，但不能强行覆盖 Genome V2/V5 或与其版本轴冲突。本文只定义其验收字段，不在此文件伪造实现。

## 4. Bxx 基准矩阵

下表的数字、样本数和容差都是 `suggested_initial_protocol`，需在正式 campaign 前由主线程统一冻结，并写入 `task_manifest.json`。它们不是已经认可的物理阈值；冻结后禁止查看结果再调门。每个 benchmark 的 `范围` 限定证据可外推的对象，超出范围应记录 `provider_match=out_of_domain; resolution=terminal_deferred`，不能扩张为全 grammar 结论；只有最终 authority 才能在完整 closure 后给出 `unsupported`。

`B06a/B06b/B06c` 是 B06 的子协议，`B07A/B07B` 是 B07 的子协议；它们细化证据范围，不新增工作单或改变 `task_manifest.json` 中的 B06/B07 依赖。

| ID / 对应要求 | 输入 | 观测 | 预注册门槛（建议初始值）与范围 | 失败分类 | 证据产物 |
|---|---|---|---|---|---|
| **B00 合同与标签擦除** / R01,R07 | 同一三 Genome bundle、mission/bounds、两进程；另取 display/family/name/benchmark 标签擦除和节点/区域/接口置换样例。 | canonical package/hash、provider route、applicability、最终判定的逐字段 diff。 | 同一 **attempt** 内同一 solver-input hash 最多真实执行一次并复用该 attempt receipt；fresh replay 或新 attempt 必须生成新的 receipt，不能用去重掩盖独立重放。hash/routing/decision 差异 `=0`。范围仅合同等价与路由。 | `program_exception`、`numerical_fail`、`unknown` 或 contract `resolution=terminal_deferred`，按失败层记录；不能当物理失败。 | canonical JSON、attempt-scoped hash/cache manifest、fresh-replay receipts、tag-erasure diff、独立 checker receipt、B00 EvidenceEnvelope。 |
| **B01 独立 MMS 解** / R03,R06 | 带已知解析场、源项、边界牵引/法向、单位和 exact solution 的 manufactured family；至少 3 个空间分辨率、两个独立实现/公式。 | 每层 L∞/L2 field error、残差、源/边界一致性、导数/积分身份、solver exit、声明的渐近区间。 | `suggested_initial_protocol`：所有声明网格 solver exit 0；代数或可精确表示的 MMS 可用残差/误差 `<=1e-8` 示例门；一般 PDE 分开冻结 residual tolerance、finest-grid error budget、`p_declared` 及 asymptotic range，粗网格不要求绝对误差 `<=1e-8`；独立实现比较按双方离散、积分和舍入误差预算冻结；仅同一可精确表示问题可用 `<=1e-9` 示例。仅证明离散实现，不证明真实物理。 | solver iteration limit 为 `numerical_fail`；公式/实现不一致为 `program_exception` 或 `numerical_fail`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；不得写 `physical_fail`。 | frozen MMS JSON、解析函数版本/hash、网格/quad manifest、residual/error/order table、两实现输出、checker exit。 |
| **B02 守恒与网格阶** / R03 | 同一 MMS/真实候选的三层以上 nested grid/time step；区域接口、外边界、源汇 ledger。 | 每个 account 的全局/区域/接口 defect、解差异、若有 exact solution 的真实误差阶；无 exact 时的三网格差、Richardson/独立误差估计、时间阶和网格 hash。 | 建议至少 3 层、每个 required account defect `<=1e-10` scaled；有 exact solution 时连续两对细化满足冻结 `p_declared` 范围；真实候选无 exact 时只可据三网格差/Richardson/独立估计报告 `proxy_discretization_order`，不得称为真实误差 order。当前 N1 `-6.15795` 明确不通过。 | 守恒 defect 数值超冻结门、负阶/不单调/缺层优先 `numerical_fail`；account 未定义是 `invalid_closure`/`resolution=terminal_deferred`；只有在收敛且适用的物理判断中独立证明守恒律违反时才是 `physical_fail`。 | per-level solution/ledger、order-or-proxy calculation、Richardson/independent estimator、quadrature/checker、失败原因和 exit。 |
| **B03 held-out 组合预测** / R02,R06 | source/shot/工况/拓扑按 candidate-independent split 分为 calibration、validation、held-out；冻结 θ、先验、噪声、缺测 mask。 | held-out observables、预测残差、coverage、参数 posterior/interval、校准与留出 ID 交集。 | 建议至少 8 个 calibration、4 个 held-out combinations，ID 交集 `=0`；held-out normalized RMSE `<= declared measurement-noise budget`，区间 coverage `>=90%`（正式数值需冻结）。范围仅已获取数据覆盖的工况。 | split 泄漏/答案进入初始化是 `program_exception`/`unknown`；预测超门是 `numerical_fail` 或 validation `physical_fail`（按量）；无数据 `physical_status=unknown; resolution=terminal_deferred`。 | split manifest、原始数据 hash/单位、inverse config、留出预测、coverage/checker receipt。 |
| **B04 非法类型/闭合/边界拒绝** / R01,R03,R07 | 逐一注入错误 rank/dim/unit/time、重复 account owner、未配对 interface flux、缺 source、越界/非闭合 boundary、空 capability axis。 | validator 是否拒绝、错误码/路径、是否执行 solver、是否污染 archive/grammar。 | 建议每类至少 5 个 mutation，100% 在 compile/provider 前拒绝；不得产生物理 evidence；错误路径稳定。 | 合法性拒绝为 `invalid_type`、`invalid_closure`、`invalid_boundary`；validator 崩溃为 `program_exception`；不可把 rejected candidate 记 `physical_fail`，也不可全 grammar 剪枝。 | mutation fixture、validator output、未执行证明、archive diff、负例 checker exit。 |
| **B05 拓扑转移** / R01,R03,R08 | 至少两个不同 capability topology（例如闭合多区域接口与开放外边界），同一 mission 字段但不同区域/接口/边界图；独立 provider manifests。 | transfer 后 canonical identity、接口 flux/traction/current、区域守恒、provider match、solver outputs。 | 建议 2 个 topology、每个至少 3 个 scenario；接口 defect `<=1e-10` scaled、外边界项显式；删除 family/name 标签后 route 不变。只在声明的两拓扑范围内有效。 | provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；接口不守恒 `numerical_fail` 或适用物理违反 `physical_fail`；图不合法 `invalid_closure`。 | parent/child manifests、topology graph/hash、独立 provider receipt、transfer ledger、comparison report。 |
| **B06（总协议）** / R03,R06 | B06a 外部空间域、B06b 场基、B06c ROM 三类独立输入、manifest 和 checker；三者不能互相代替。 | 分别观察外域截断敏感性、场基 tail bound、ROM residual/OOD/held-out/high-fidelity 复验。 | 只要求本工单实际使用的方法对应子协议通过；不使用 ROM 时 B06c 不适用并记录无 ROM 路径证明。任何子协议的通过都不能外推为另一子协议通过；UP3-03 可选 ROM 不阻塞主链。 | 各子协议按自身的 `numerical_fail`、`physical_fail`、`program_exception` 或 `resolution=terminal_deferred` 分类。 | B06a/B06b/B06c 子产物及总协议汇总 envelope；不把外域截断等同于丢系数。 |
| **B06a 外部空间域截断** / R03,R06 | 物理外域半径、外域网格、远场/外边界条件、截断层级和同一 candidate-bound interior；不改变场基系数。 | 半径、外域 mesh、BC 变化下的边界/内部 observables、守恒 defect、敏感性曲线。 | 建议至少 3 个外域半径、2 个外域网格级别、2 个适用 BC 方案；结果在预注册外域误差预算内稳定，且截断敏感性有范围。该协议只覆盖外域/半径/mesh/BC，不覆盖系数截断。 | 外域求解不收敛或敏感性超门 `numerical_fail`；BC 物理约束违反才 `physical_fail`；没有合法外域 provider 为 `provider_match=...; resolution=terminal_deferred`。 | domain/radius/mesh/BC manifest、每次 solver input hash、敏感性表/图、外域 checker receipt。 |
| **B06b 场基截断 tail** / R03,R06 | 完整源 boundary/interior basis、截断系数、保留/丢弃项、采样域和单位；外域设置固定。 | 每个丢弃项的解析/区间 tail bound、边界/内部场误差、导数/积分误差。 | 建议每个丢弃项有可复算 bound；声明域内 field error `<=1e-8`（按 SI/declared scale）或使用 UP0-02 冻结的误差预算；该门不代表外域截断通过。 | bound 缺失 `resolution=terminal_deferred`；误差超门 `numerical_fail`；真实适用边界约束违反才 `physical_fail`。 | full/truncated coefficient hashes、tail-bound derivation、basis evaluator、误差表、独立 checker。 |
| **B06c ROM/OOD/held-out** / R03,R06 | basis/POD/约束投影训练集、未参与构基的 validation/held-out geometry 与组合、OOD detector、完整高保真 provider。 | ROM residual、守恒/约束、OOD 命中率、held-out error、high-fidelity recheck 和构基/在线成本。 | 建议至少 1 个 held-out geometry、1 个 held-out combination、1 次高保真复验；OOD 必须拒绝或升级；ROM 误差达到冻结 budget 且成本收益扣除构基成本。只有 basis 和 in-domain residual 不能晋升。 | OOD 漏检或 trace 错误 `program_exception`；误差/守恒超门 `numerical_fail`；缺 high-fidelity/OOD provider `resolution=terminal_deferred`；ROM 不得填补闭合缺口。 | basis/training split/hash、OOD report、held-out outputs、high-fidelity output、cost/error report、checker receipt。 |
| **B07（总协议）** / R02,R04,R06 | B07A 源硬件 inverse design 与 B07B 真实参考隐参 inverse 的独立输入、适用域和 evidence；两者不能互相授信。 | 分别观察可制造源设计误差/资源闭合，与真实参考隐藏参数识别/留出预测。 | B07A 通过不产生 R02 credit；只有 B07B 的真实来源、隐藏答案、识别和 held-out 全通过，才能给 R02 inverse credit。 | 子协议分别按执行、数值、物理和 `resolution=terminal_deferred` 分类；不能把 synthetic design 失败扩展为真实 reference 不可逆。 | B07A/B07B 子产物及总协议汇总 envelope，含独立性分组。 |
| **B07A 源硬件逆设计** / R04,R05 | synthetic target field/source demand、可制造硬件参数域、电源/回流/热约束、candidate-bound forward model；独立 forward checker。 | 目标场/源误差、源电流/功率、热/结构 margins、实现源替换后的 forward 结果和多起点稳定性。 | 建议至少 8 个多起点；目标误差 `<=` UP0-02 冻结的 declared tolerance，所有资源/回流/热结构硬门通过；可使用合成 target，但不得计入 R02。 | optimizer/forward 不收敛 `numerical_fail`；资源或材料硬门违反 `physical_fail`；无适用 source provider `resolution=terminal_deferred`。 | synthetic target hash、design manifest、multi-start trace、hardware/source output、independent forward receipt、engineering ledger。 |
| **B07B 真实参考隐参逆恢复** / R02,R06 | provenance 完整的真实参考装置/实验数据、观测 y、真实隐藏 θ、噪声/缺测、candidate-independent calibration/validation/held-out split；答案不得进入 seed/cache。 | θ recovery error、forward round-trip、Jacobian rank/identifiability、multi-start spread、held-out observations。 | 建议至少 8 个明显不同初值、2 种噪声/缺测条件；隐藏参数相对误差 `<=2%`（或 source uncertainty budget，先冻结）；held-out normalized error `<=1` noise budget；rank/condition report 必须存在。范围只覆盖真实 source 字段和工况；无真实 source/hidden θ/held-out 时不得给 R02 credit。 | optimizer 未收敛/秩不足 `numerical_fail`/`unknown`；source 字段、数据或 basis 缺失 `physical_status=unknown; resolution=terminal_deferred`；适用观测违反门才 `physical_fail`；不能把同源重建当独立验证。 | raw source/data hash、split/inverse manifest、multi-start traces、identifiability report、held-out prediction、round-trip receipt。 |
| **B08 源到工程闭环** / R04,R05,R06 | UP3 已通过的 candidate-bound geometry/fields，或 B07A 的实际源/硬件参数；线圈/电路、供能、热、结构、材料、控制、故障、启动/停机、燃料循环输入；完整周期边界。B07B 真实参考逆恢复为可选增强输入，不是前置条件。 | power/energy ledger、供能与回流、热/结构 margin、fault response、跨模块 hash、uncertainty/discrepancy。 | 建议每个能量项单列且无重复；周期 ledger residual `<=1e-6` relative；所有 required fault scenarios 有有限输出和安全状态；热/结构 margins `>0`，具体安全系数在 campaign 前冻结。范围是已声明工程边界。 | 上游 candidate-bound 物理未收敛 `resolution=terminal_deferred`；电路/热结构求解不收敛 `numerical_fail`；适用 margin 违反 `physical_fail`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`。 | engineering input/output manifests、周期 ledger、fault traces、thermal/structural reports、cross-hash join、independent checker。 |
| **B09 条件 egraph 改写** / R01,R08 | typed AST/program、`ConditionalRewriteSetV1`、registry capability、每条 rewrite 的 side conditions（units、rank、conservation、boundary/time semantics）；规则顺序和预算配置。 | 条件是否满足、e-class membership、trace replay、semantic equivalence、预算使用、配置确定性；饱和闭包（如实际达到）。 | 建议 100% rewrite trace 可独立重放；条件不满足时 0 次合并；规则顺序与预算必须冻结，同一配置重放 hash 一致；仅当达到同一等价闭包且规范化确定时比较集合；有限预算未饱和记 `incomplete`，不判不等价；预算上限硬拒绝。只证明声明的 rewrite theory，不证明物理等价。 | 条件失败为 `not_applicable` 或 `resolution=terminal_deferred`；trace/semantic mismatch 为 `program_exception` 或 `numerical_fail`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；不能把 egraph unique 当原创性。 | ruleset/registry hash、condition proof、trace JSONL、replay output、budget report、saturation/incomplete marker、independent checker。 |
| **B10 搜索能力增量** / R08 | 冻结 baseline emitter 与新 emitter、相同 seed/budget/cost、behavior cells、capability signature、promotion rules；记录失败 frontier。 | unique semantic/capability cells、合法 descendants、provider coverage、hard-gate survivor、成本和 false-negative audit。 | 建议 paired campaign：至少 50 个 semantic/capability cells、每组同预算；新能力至少进入 2 个此前不可达 cells，且 baseline 可达 cells 的 hard-gate 通过率不下降超过预先冻结余量；随机审计永久剪枝 100%。不是“proposal 数更多”。 | proposer 崩溃归一化为 `program_exception`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；硬门失败 `numerical_fail/physical_fail`；剪枝错误 `program_exception`；单 candidate 失败不能删 grammar。 | frozen campaign manifest、seed/shard plan、proposal/compiled/failure/archive counts、capability delta、prune certificates、merge audit。 |
| **B11 独立重放** / R07,R10 | 新鲜工作区/环境、source/data/provider/checker versions、完整 command list、candidate/mission/scenario/solver hashes；独立执行者或独立 process。 | outputs、exit codes、hash joins、scientific classification、artifact completeness、乱序/恢复一致性。 | 建议 2 次 fresh replay；required artifact completeness `100%`，identity/hash join `100%`；数值量在冻结 tolerance 内，terminal classification 相同。B11 只证明可复现性，不自动提供独立物理验证、双代码验证或 validation credit；恢复不得重复计 evidence。 | 缺 artifact/中断 `human_interruption/not_executed/unknown`；输出差异超门 `numerical_fail`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；不能用旧 run 的 exit 代替新 replay。 | environment lock、commands、stdout/stderr、exit files、hash manifest、independent checker report、replay receipt。 |
| **B12 周期正净输出** / R05,R07,R10 | candidate-bound whole-device full-cycle input/output energy，供能、回流、转换、维护、停机、燃料和不确定性；冻结系统边界和周期。 | `E_net=E_out-E_in`、每项 ledger、scenario distribution/model discrepancy、lower confidence bound、重复计量检查。 | 建议正式门为在声明 uncertainty/model-discrepancy 协议下 `lower_bound(E_net)>0`，且每个 required scenario 通过；具体置信水平、周期和 margin 必须先冻结。设计目标/conditional range 不可充作 net output。 | solver/ledger 不闭合 `numerical_fail`；完整适用账本为负 `physical_fail`；缺项/无分布 `physical_status=unknown; resolution=terminal_deferred`；不确定性缺失 `unknown`。 | immutable whole-device energy ledger、scenario inputs、uncertainty/discrepancy report、independent recomputation、authority envelope。 |
| **B13 独立原创性** / R09 | candidate 的 canonical structural/mechanism/behavior descriptors、时间戳、内部 archive、外部文献/专利查询范围和独立审查人。 | 数学等价、结构差异、行为差异、机制差异、外部相似项、披露日期和覆盖范围。 | 建议至少两名独立审查人、两类外部来源、查询式/日期/覆盖范围可复放；不得预设“hash 唯一=原创”。阈值由 R09 campaign 冻结，结果不能反向改搜索门。 | 查询缺失 `resolution=terminal_deferred`；等价未识别 `program_exception`；外部证据冲突 `unknown`；不能因低 fidelity 行为差异宣布原创。 | descriptor/hash archive、等价证明、查询日志/来源 hash、独立 review reports、scope-limited originality envelope。 |

### 4.1 阈值冻结与数据切分规则

正式 campaign 运行前，主线程必须把上述建议值转换成版本化 `acceptance_protocol`，同时冻结单位、归一化尺度、rounding、随机种子、grid、solver iteration/stop rules、provider registry、独立性分组和 checker 版本。任何看过结果后的阈值调整都必须创建新 protocol/campaign，并保留旧结果。

校准数据、调参数据、validation 数据和 held-out 数据必须以不可重叠的 artifact ID、shot、scenario 或 topology identity 切分；同源派生量也不能跨 split 泄漏。`held_out_combination` 要在组合层去重，不能只改变一列数值就宣称独立组合。

## 5. R01–R10 父目标关账矩阵

R01–R10 是完整父目标，不因 UP 阶段变小。每行的“当前状态”是 2026-09-13 最新恢复事实；`partial`、`screen_only`、`deferred`、`unsupported` 都不是 accepted。

| ID | 必须保留的父目标 | 必需证据组合 | 当前状态（as-of） | 终局接受条件 |
|---|---|---|---|---|
| **R01** | 同一通用生产链处理已知参考与新候选，标签、family 和 benchmark 身份不能改变物理路由。 | B00、B04、B05、B10、B11；三 Genome refs/hash、candidate/solver identity join。 | `partial`：有 candidate binding、capability routing 和局部执行。 | UP0–UP3 统一链通过；label-erasure、非法拒绝、拓扑转移、fresh replay 全通过。 |
| **R02** | ITER 等参考装置可表示并真正反解，包括描述往返、隐藏参数恢复、多起点、可识别性和 held-out 预测。 | B03、B06、B07；真实 source provenance、完整 interior/boundary basis 和独立留出。 | `not_implemented_in_current_chain`；现有 W03/W09–W21 仍有 source/basis/provider/held-out gap。 | 至少一个真实 reference 在适用域内通过 B03/B07 全门；ITER 设计目标不得替代实验 validation。 |
| **R03** | 物理方程、空间/时间、守恒、边界、闭合、稳定性、损失和输运达到声明深度。 | B01、B02、B05、B06、B08；candidate-bound provider 与独立数值 checker。 | `failed_current_attempt`：W24 四 case exit 4/iteration_limit；N1 有负观察阶。 | 所有 required cases 收敛，守恒和网格/时间阶通过，模型闭合无 unresolved deferred。 |
| **R04** | 整机工程与控制：线圈/电路、供能、热/结构/材料、环境、故障、启停、燃料循环和控制反馈。 | B08、B12；工程 scenario、fault traces、供能/热/结构 ledger。 | `partial_local_subsystem`：仅有拾取工程子系统。 | 全部 required engineering scenarios candidate-bound、可重放、边界闭合且 margins 通过。 |
| **R05** | 全周期站级正净输出，边界冻结、无漏项无重复计能，并在不确定性/模型差异下成立。 | B08、B12、B11；独立 energy ledger 与 lower-bound 计算。 | `not_implemented_in_current_chain`；没有 complete candidate-bound plant power producer。 | B12 的每个 required scenario 和 uncertainty lower bound 均为正；不能使用 ITER Q=10 或 conditional range 代替。 |
| **R06** | 独立物理验证与 UQ：独立数据/solver、校准验证隔离、误差、适用域、模型差异和传播。 | B01、B03、B06、B07、B08、B11；independence groups 与 validation artifacts。 | `missing_data_and_providers`；当前 physical validation 未执行，软件 benchmark credit 为 0。 | 独立来源/代码/数据实际执行且适用；不确定性和 discrepancy 可追溯传播。 |
| **R07** | 高等级 evidence 和 final authority 可达；screen/missing/cross-boundary/replay 不能冒充。 | B00、B04、B06、B11、B12、B13；`FinalWholeDeviceAuthorityV4` envelope。 | `not_implemented_in_current_chain`；现有路径有意保持 screen/deferred 上限。 | 所有 required obligations 有适用 evidence，无 unresolved deferred；authority 独立审计并写 claim ceiling。 |
| **R08** | G1/G2/G3 开放式发现闭环：真实后代→物理求解→档案回写→后续提议，多机制/几何/实现变化可达，失败可恢复。 | B05、B09、B10、B11；multi-emitter、failure frontier、archive、resume receipts。 | `partial_queue_only`；W23 是 G1 两代 0D screen，W24 是一对 G2 screen，仍 `R08_accepted=false`。 | UP3–UP5 形成跨 Genome 的真实闭环；搜索能力增量和独立 replay 通过，非单一局部赢家。 |
| **R09** | 独立原创性证据：数学等价、结构/行为/机制差异及文献/专利检索、日期和覆盖范围。 | B09、B10、B13；独立审查和 scope-limited novelty records。 | `not_implemented_in_current_chain`；没有完整 external prior-art/originality pipeline。 | B13 在已声明 scope 内通过；内部唯一哈希只能是线索，不能自动给出外部原创性。 |
| **R10** | 新鲜环境可复现交付与原始目标关账，至少一个新候选同时通过 R03–R09。 | B00–B13 中适用项、B11、final authority、代码/数据/审查包。 | `not_achieved`；没有同时通过 final hard gates 的新候选。 | fresh replay 成功、证据完整、authority 发 L4（或更高）scope 的 `credible_within_scope`；否则保留 `platform_ready` 与 `discovery_goal_achieved` 的分离状态。 |

## 6. 执行与验收顺序

主线程执行时沿用唯一 work-order manifest，推荐顺序为：

```text
冻结 UP0 protocol
  → UP1 三 Genome/组件 schema 与负例
  → UP2 离散空间、接口、源项和边界编译
  → B01/B02/B04/B05/B06 数值与闭合验收
  → UP3 合法 G1/G2/G3 组合自动执行
  → B03/B07/B08 来源逆设计与工程反馈
  → UP5/B09/B10 条件 egraph 与能力增量
  → B11 独立重放
  → B12/B13、FinalWholeDeviceAuthorityV4、UP6 R01–R10
```

每次 shard 先保存 frozen manifest 和输入 hash，再执行 provider；全部 shard 到 terminal state 后才 merge frontier。merge 必须拒绝 grid、预算、schema、provider hash 不一致，空/损坏 JSONL、重复 solver input、跨 campaign evidence 和缺失 independent group。恢复运行复用已完成 evidence，但生成新的 recovery receipt，不重复记账。

报告中分别列出 proposal actions、unique prefixes、proof-pruned prefixes、compiled structures、active/dormant/failure members、materialized physical subjects、unique solver inputs、各 stage pass/fail/unknown/deferred、integrated executions、terminal dispositions 和各 evidence level 的 credible count。这些数量不能相加称为“装置数”。

## 7. 当前必须统一的事项

以下内容应由主线程在 `16_execution_work_orders.md` / `task_manifest.json` 中统一，本文不另立编号：

1. UP0-01/UP0-02 共同使用的三 Genome contract refs、mission/grammar/bounds/scenario 和 acceptance protocol hash。
2. B01–B13 的单位、归一化尺度、样本数、容差、置信水平、solver stop rule 和适用域；本文的数字只是假设起点。
3. manifest 必须引用 `runs/goal_recovery_20260913_012528_cst/goal.json` 及其 source hash；`docs/reports/goal_recovery_20260913/goal.json` 仍是不存在的路径，不得再作为目标输入。
4. W24 resume 的 terminal verification、parent/child paired audit、相关回归和中断 receipt 是否已形成新的可审计 run；在此之前 W24 仍按中断/待验证处理。
5. W22 的非收敛 replay、N1 负网格阶、外部 boundary/current closure gap 如何映射到下一工作单；不得以重命名或提高迭代上限掩盖分类。
6. candidate failure frontier、dormant/revival、永久 proof-pruning 的数据结构和独立 checker 所属 authority；失败 candidate 不得全 grammar 剪除。
7. ROM 的 basis、训练域、OOD detector、held-out geometry/组合和 high-fidelity recheck 的具体 provider；仅有低保真 residual 的 ROM 不得晋升。

在这些项冻结前，不得把本文件中的 suggested threshold 报为“已认可”，也不得将本文件存在、focused tests 通过、入口 exit 0 或 run 目录生成计为 R01–R10 acceptance。

## 8. 交付前最小审计清单

交付给最终 authority 前，审计器应能在新鲜工作区只依赖 manifest 和内容寻址 artifact 完成以下检查：

- 当前源码/dirty hash、数据来源、provider/backend、checker 版本可重建；
- candidate、mission、scenario、physical subject、solver input 和 provider receipt 哈希逐层相等；
- applicable 与 not_applicable 均有理由，terminal_deferred 未被压成 unsupported 或 pass；
- solver exit、process exit、verification exit 和 independent replay exit 分开显示；
- 数值失败、物理失败、程序异常、人为中断、未执行、能力缺口和未知状态分开显示；
- MMS、守恒/网格阶、held-out、非法负例、拓扑转移、边界截断、source inverse、工程闭环、egraph、搜索增量和独立 replay 的产物均存在或明确标为缺口；
- ROM 具有 basis、域、OOD、held-out、高保真复验五类信息；
- 净输出由完整周期 energy ledger 和冻结不确定性协议计算，任何设计目标、conditional range、proxy score 或旧结果都没有进入 positive evidence；
- 最终 `credible_within_scope` 只由 `FinalWholeDeviceAuthorityV4` 发出，并同时列出 scope、claim ceiling、passed/failed/unknown/unsupported obligations 与 remaining gaps。

因此，本文完成后得到的是可执行的验收合同和当前基线记录；截至上述 as-of 时刻，项目仍没有可信完整物理装置候选，且任何 UP 阶段的局部成功都不能单独关闭冻结父目标。
