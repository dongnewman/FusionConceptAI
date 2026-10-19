# 验收规范与当前信用范围

更新2026-10-09。已完成任务操作步骤移出活动规划；本章保留验收合同、B00/B04覆盖与R01–R10，不记录逐轮运行。当前接口/实际結果/阻塞在[16](16_execution_work_orders.md)与[README](README.md)，原始命令/退出/资源/独立结论从记录明示路径读取。文档检查不构成数值或物理验收。

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

### 3.1 参考装置、资料与能力就绪门

参考装置验收必须区分四种资料/能力层，名称只保留为 provenance 标签，不得硬编码到 provider 路由、物理分支或通过条件：

| 参考层 | 可验收内容 | 就绪门 | 未达到就绪门时的上限 |
|---|---|---|---|
| ITER 设计 | 几何、线圈/电流、平衡、加热和单位的表示往返与 forward design consistency | 版本化设计来源、坐标/单位、可物化 G1/G2/G3 字段和适用域齐全；设计目标/Q 不能当实测观测或净电 | design reference / synthetic screen；不关闭实测 R02、R05 或 L5 |
| MAST 实测 | 真实观测反演、校准/validation/held-out | 原始 shot/通道、诊断定义、误差/缺测、已知输入、许可、candidate-independent split 和同链 forward 可复核 | 缺一项即 `physical_status=unknown; resolution=terminal_deferred`，不授真实 R02 credit |
| HELIOTRON 数值/非轴对称 | 几何、基函数、非轴对称 solver 的数值复放和 capability 检查 | solver/backend、几何/边界/基函数输入、版本和适用域齐全；同一家族复算同一状态不算实验独立性 | declared-scope numerical evidence；不能替代实测或独立数据 |
| C-2W pending | 待获取的 source/diagnostic/geometry/solver 能力 | 数据、许可、观测算子和可执行 provider 尚未齐全时保留 `required + terminal_deferred` | pending capability；不能作为其他装置的替代证据 |

“资料就绪”不是网页、参数表、局部 basis 或模板存在，而是能提供真实输入、观测 `y`、观测算子 `H`、未知量 `theta`、误差/缺测、split manifest 和可执行 provider。参考路径与新候选共用同一编译/评价入口；mission 决定适用 obligations，不能以装置名或 anchor copy 绕过门。

### 3.2 参考反演和完整链集成门

每个真实参考 benchmark 在优化前冻结来源及 SHA、坐标/单位/时间、诊断响应、测量误差、已知输入 `x`、未知参数 `theta`、`y_cal`、独立 `y_val`、边界/先验、停止条件和成功门。正向函数必须与新候选共用：

```text
theta -> G1/G2/G3 bundle -> common compile/evaluate F -> H(F(...)) -> observations
```

验收顺序为表示往返；解析/MMS 或合成隐藏真值的 synthetic recovery；真实观测的多起点反演和 rank/condition/等价类分析；训练未访问的 shot/channel/time/geometry/topology held-out forward prediction；第二进程或不同实现的 hash、单位、残差和分类复核。答案不得进入 seed、cache、basis、初值或 benchmark-only 构造器。局部可识别参数只能关闭对应子范围，不能宣布整机反演完成。

局部成果接入正式生产链还必须同时有：消费者入口及 schema、实际调用 receipt、真实输入 hash、下游物理/工程/诊断闭环和独立复放。静态合同、focused test、component-level pass、孤立数值、搜索 proposal 或只 anchor 复制均不能计为 `integrated_execution`，也不能用来覆盖完整能力缺口。缺任一项时保留 `contract_only`、`screen_only`、`prepared_not_executed` 或 `terminal_deferred`。

## 4. Bxx 基准矩阵

下表的数字、样本数和容差都是 `suggested_initial_protocol`，需在正式 campaign 前由主线程统一冻结，并写入 `task_manifest.json`。它们不是已经认可的物理阈值；冻结后禁止查看结果再调门。每个 benchmark 的 `范围` 限定证据可外推的对象，超出范围应记录 `provider_match=out_of_domain; resolution=terminal_deferred`，不能扩张为全 grammar 结论；只有最终 authority 才能在完整 closure 后给出 `unsupported`。

`B06a/B06b/B06c` 是 B06 的子协议，`B07A/B07B` 是 B07 的子协议；它们细化证据范围，不新增工作单或改变 `task_manifest.json` 中的 B06/B07 依赖。

| ID / 对应要求 | 输入 | 观测 | 预注册门槛（建议初始值）与范围 | 失败分类 | 证据产物 |
|---|---|---|---|---|---|
| **B00 合同与标签擦除** / R01,R07 | 同一三 Genome bundle、mission/bounds、两进程；另取 display/family/name/benchmark 标签擦除和节点/区域/接口置换样例。 | canonical package/hash、provider route、applicability、最终判定的逐字段 diff。 | 同一 **attempt** 内同一 solver-input hash 最多真实执行一次并复用该 attempt receipt；fresh replay 或新 attempt 必须生成新的 receipt，不能用去重掩盖独立重放。hash/routing/decision 差异 `=0`。范围仅合同等价与路由。 | `program_exception`、`numerical_fail`、`unknown` 或 contract `resolution=terminal_deferred`，按失败层记录；不能当物理失败。 | canonical JSON、attempt-scoped hash/cache manifest、fresh-replay receipts、tag-erasure diff、独立 checker receipt、B00 EvidenceEnvelope。 |
| **B01 独立 MMS 解** / R03,R06 | 带已知解析场、源项、边界牵引/法向、单位和 exact solution 的 manufactured family；至少 3 个空间分辨率、两个独立实现/公式。 | 每层 L∞/L2 field error、残差、源/边界一致性、导数/积分身份、solver exit、声明的渐近区间。 | `suggested_initial_protocol`：所有声明网格 solver exit 0；代数或可精确表示的 MMS 可用残差/误差 `<=1e-8` 示例门；一般 PDE 分开冻结 residual tolerance、finest-grid error budget、`p_declared` 及 asymptotic range，粗网格不要求绝对误差 `<=1e-8`；独立实现比较按双方离散、积分和舍入误差预算冻结；仅同一可精确表示问题可用 `<=1e-9` 示例。仅证明离散实现，不证明真实物理。 | solver iteration limit 为 `numerical_fail`；公式/实现不一致为 `program_exception` 或 `numerical_fail`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；不得写 `physical_fail`。 | frozen MMS JSON、解析函数版本/hash、网格/quad manifest、residual/error/order table、两实现输出、checker exit。 |
| **B02 守恒与网格阶** / R03 | 同一 MMS/真实候选的三层以上 nested grid/time step；区域接口、外边界、源汇 ledger。 | 每个 account 的全局/区域/接口 defect、解差异、若有 exact solution 的真实误差阶；无 exact 时的三网格差、Richardson/独立误差估计、时间阶和网格 hash。 | 建议至少 3 层、每个 required account defect `<=1e-10` scaled；有 exact solution 时连续两对细化满足冻结 `p_declared` 范围；真实候选无 exact 时只可据三网格差/Richardson/独立估计报告 `proxy_discretization_order`，不得称为真实误差 order。当前 N1 `-6.15795` 明确不通过。 | 守恒 defect 数值超冻结门、负阶/不单调/缺层优先 `numerical_fail`；account 未定义是 `invalid_closure`/`resolution=terminal_deferred`；只有在收敛且适用的物理判断中独立证明守恒律违反时才是 `physical_fail`。 | per-level solution/ledger、order-or-proxy calculation、Richardson/independent estimator、quadrature/checker、失败原因和 exit。 |
| **B03 held-out 组合预测** / R02,R06 | 有 provenance 的真实 source/shot/工况/拓扑资料；观测 `y`、诊断算子 `H`、未知 `theta`；按 candidate-independent split 分为 calibration、validation、held-out；冻结 G1/G2/G3 映射、先验、噪声、缺测 mask 和同生产链 forward。 | held-out observables、预测残差、coverage、参数 posterior/interval、校准与留出 ID 交集、Genome bundle/hash 和 forward round-trip。 | 建议至少 8 个 calibration、4 个 held-out combinations，ID 交集 `=0`；held-out normalized RMSE `<= declared measurement-noise budget`，区间 coverage `>=90%`（正式数值需冻结）。范围仅已获取数据覆盖的工况；缺真实资料或 provider 不得用设计模板补齐。 | split 泄漏/答案进入初始化或 anchor copy 是 `program_exception`/`unknown`；预测超门是 `numerical_fail` 或 validation `physical_fail`（按量）；无数据/观测算子/适用 provider 为 `physical_status=unknown; resolution=terminal_deferred`。 | source/data/diagnostic hash、Genome mapping、split manifest、inverse config、round-trip、held-out forward prediction、coverage/checker receipt。 |
| **B04 非法类型/闭合/边界拒绝** / R01,R03,R07 | 逐一注入错误 rank/dim/unit/time、重复 account owner、未配对 interface flux、缺 source、越界/非闭合 boundary、空 capability axis。 | validator 是否拒绝、错误码/路径、是否执行 solver、是否污染 archive/grammar。 | 建议每类至少 5 个 mutation，100% 在 compile/provider 前拒绝；不得产生物理 evidence；错误路径稳定。 | 合法性拒绝为 `invalid_type`、`invalid_closure`、`invalid_boundary`；validator 崩溃为 `program_exception`；不可把 rejected candidate 记 `physical_fail`，也不可全 grammar 剪枝。 | mutation fixture、validator output、未执行证明、archive diff、负例 checker exit。 |
| **B05 拓扑转移** / R01,R03,R08 | 至少两个不同 capability topology（例如闭合多区域接口与开放外边界），同一 mission 字段但不同区域/接口/边界图；独立 provider manifests。 | transfer 后 canonical identity、接口 flux/traction/current、区域守恒、provider match、solver outputs。 | 建议 2 个 topology、每个至少 3 个 scenario；接口 defect `<=1e-10` scaled、外边界项显式；删除 family/name 标签后 route 不变。只在声明的两拓扑范围内有效。 | provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；接口不守恒 `numerical_fail` 或适用物理违反 `physical_fail`；图不合法 `invalid_closure`。 | parent/child manifests、topology graph/hash、独立 provider receipt、transfer ledger、comparison report。 |
| **B06（总协议）** / R03,R06 | B06a 外部空间域、B06b 场基、B06c ROM 三类独立输入、manifest 和 checker；三者不能互相代替。 | 分别观察外域截断敏感性、场基 tail bound、ROM residual/OOD/held-out/high-fidelity 复验。 | 只要求本工单实际使用的方法对应子协议通过；不使用 ROM 时 B06c 不适用并记录无 ROM 路径证明。任何子协议的通过都不能外推为另一子协议通过；UP3-03 可选 ROM 不阻塞主链。 | 各子协议按自身的 `numerical_fail`、`physical_fail`、`program_exception` 或 `resolution=terminal_deferred` 分类。 | B06a/B06b/B06c 子产物及总协议汇总 envelope；不把外域截断等同于丢系数。 |
| **B06a 外部空间域截断** / R03,R06 | 物理外域半径、外域网格、远场/外边界条件、截断层级和同一 candidate-bound interior；不改变场基系数。 | 半径、外域 mesh、BC 变化下的边界/内部 observables、守恒 defect、敏感性曲线。 | 建议至少 3 个外域半径、2 个外域网格级别、2 个适用 BC 方案；结果在预注册外域误差预算内稳定，且截断敏感性有范围。该协议只覆盖外域/半径/mesh/BC，不覆盖系数截断。 | 外域求解不收敛或敏感性超门 `numerical_fail`；BC 物理约束违反才 `physical_fail`；没有合法外域 provider 为 `provider_match=...; resolution=terminal_deferred`。 | domain/radius/mesh/BC manifest、每次 solver input hash、敏感性表/图、外域 checker receipt。 |
| **B06b 场基截断 tail** / R03,R06 | 完整源 boundary/interior basis、截断系数、保留/丢弃项、采样域和单位；外域设置固定。 | 每个丢弃项的解析/区间 tail bound、边界/内部场误差、导数/积分误差。 | 建议每个丢弃项有可复算 bound；声明域内 field error `<=1e-8`（按 SI/declared scale）或使用 UP0-02 冻结的误差预算；该门不代表外域截断通过。 | bound 缺失 `resolution=terminal_deferred`；误差超门 `numerical_fail`；真实适用边界约束违反才 `physical_fail`。 | full/truncated coefficient hashes、tail-bound derivation、basis evaluator、误差表、独立 checker。 |
| **B06c ROM/OOD/held-out** / R03,R06 | basis/POD/约束投影训练集、未参与构基的 validation/held-out geometry 与组合、OOD detector、完整高保真 provider。 | ROM residual、守恒/约束、OOD 命中率、held-out error、high-fidelity recheck 和构基/在线成本。 | 建议至少 1 个 held-out geometry、1 个 held-out combination、1 次高保真复验；OOD 必须拒绝或升级；ROM 误差达到冻结 budget 且成本收益扣除构基成本。只有 basis 和 in-domain residual 不能晋升。 | OOD 漏检或 trace 错误 `program_exception`；误差/守恒超门 `numerical_fail`；缺 high-fidelity/OOD provider `resolution=terminal_deferred`；ROM 不得填补闭合缺口。 | basis/training split/hash、OOD report、held-out outputs、high-fidelity output、cost/error report、checker receipt。 |
| **B07（总协议）** / R02,R04,R06 | B07A 源硬件 inverse design 与 B07B 真实参考隐参 inverse 的独立输入、适用域和 evidence；两者不能互相授信。 | 分别观察可制造源设计误差/资源闭合，与真实参考隐藏参数识别/留出预测。 | B07A 通过不产生 R02 credit；只有 B07B 的真实来源、隐藏答案、识别和 held-out 全通过，才能给 R02 inverse credit。 | 子协议分别按执行、数值、物理和 `resolution=terminal_deferred` 分类；不能把 synthetic design 失败扩展为真实 reference 不可逆。 | B07A/B07B 子产物及总协议汇总 envelope，含独立性分组。 |
| **B07A 源硬件逆设计** / R04,R05 | synthetic target field/source demand、可制造硬件参数域、电源/回流/热约束、candidate-bound forward model；独立 forward checker。 | 目标场/源误差、源电流/功率、热/结构 margins、实现源替换后的 forward 结果和多起点稳定性。 | 建议至少 8 个多起点；目标误差 `<=` UP0-02 冻结的 declared tolerance，所有资源/回流/热结构硬门通过；可使用合成 target，但不得计入 R02。 | optimizer/forward 不收敛 `numerical_fail`；资源或材料硬门违反 `physical_fail`；无适用 source provider `resolution=terminal_deferred`。 | synthetic target hash、design manifest、multi-start trace、hardware/source output、independent forward receipt、engineering ledger。 |
| **B07B 真实参考隐参逆恢复** / R02,R06 | provenance 完整的真实参考装置/实验数据、观测 `y`、诊断算子 `H`、真实隐藏 `theta` 或明确可评估的未知量范围、噪声/缺测、candidate-independent calibration/validation/held-out split；答案不得进入 seed/cache。反演必须生成 G1/G2/G3 bundle 并调用与新候选相同的 forward。 | 有独立真值时 theta recovery error；无真值时后验/等价类与预测校准，Genome/physical round-trip、Jacobian rank/identifiability、multi-start spread、held-out observations、下游 consumer receipt 和独立复放。 | 建议至少 8 个明显不同初值、2 种噪声/缺测条件；已知且与反演隔离的独立真值存在时，隐藏参数相对误差 `<=2%`（或先冻结的 source uncertainty budget）；真实实测无真值时禁止填写 recovery error，改验可识别等价类、后验/区间、预测校准和独立留出；synthetic known-theta 只算 synthetic recovery，不替代实测 validation；held-out normalized error `<=1` noise budget；rank/condition report、G1/G2/G3 字段映射和 common-forward receipt 必须存在。范围只覆盖真实 source 字段和工况；无真实 source/观测/诊断/held-out 时不得给 R02 credit。 | optimizer 未收敛/秩不足 `numerical_fail`/`unknown`；source 字段、数据、诊断或 basis 缺失 `physical_status=unknown; resolution=terminal_deferred`；适用观测违反门才 `physical_fail`；不能把同源重建、anchor copy 或同一日志二次读取当独立验证。 | raw source/data/diagnostic hash、Genome mapping、split/inverse manifest、multi-start traces、identifiability report、common-forward and held-out prediction、consumer/downstream receipt、independent replay。 |
| **B08 源到工程闭环** / R04,R05,R06 | UP3 已通过的 candidate-bound geometry/fields，或 B07A 的实际源/硬件参数；线圈/电路、供能、热、结构、材料、控制、故障、启动/停机、燃料循环输入；完整周期边界。B07B 真实参考逆恢复为可选增强输入，不是前置条件。 | power/energy ledger、供能与回流、热/结构 margin、fault response、跨模块 hash、uncertainty/discrepancy。 | 建议每个能量项单列且无重复；周期 ledger residual `<=1e-6` relative；所有 required fault scenarios 有有限输出和安全状态；热/结构 margins `>0`，具体安全系数在 campaign 前冻结。范围是已声明工程边界。 | 上游 candidate-bound 物理未收敛 `resolution=terminal_deferred`；电路/热结构求解不收敛 `numerical_fail`；适用 margin 违反 `physical_fail`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`。 | engineering input/output manifests、周期 ledger、fault traces、thermal/structural reports、cross-hash join、independent checker。 |
| **B09 条件 egraph 改写** / R01,R08 | typed AST/program、`ConditionalRewriteSetV1`、registry capability、每条 rewrite 的 side conditions（units、rank、conservation、boundary/time semantics）；规则顺序和预算配置。 | 条件是否满足、e-class membership、trace replay、semantic equivalence、预算使用、配置确定性；饱和闭包（如实际达到）。 | 建议 100% rewrite trace 可独立重放；条件不满足时 0 次合并；规则顺序与预算必须冻结，同一配置重放 hash 一致；仅当达到同一等价闭包且规范化确定时比较集合；有限预算未饱和记 `incomplete`，不判不等价；预算上限硬拒绝。只证明声明的 rewrite theory，不证明物理等价。 | 条件失败为 `not_applicable` 或 `resolution=terminal_deferred`；trace/semantic mismatch 为 `program_exception` 或 `numerical_fail`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；不能把 egraph unique 当原创性。 | ruleset/registry hash、condition proof、trace JSONL、replay output、budget report、saturation/incomplete marker、independent checker。 |
| **B10 搜索能力增量** / R08 | 冻结 baseline emitter 与新 emitter、相同 seed/budget/cost、behavior cells、capability signature、promotion rules；记录失败 frontier。 | unique semantic/capability cells、合法 descendants、provider coverage、hard-gate survivor、成本和 false-negative audit。 | 建议 paired campaign：至少 50 个 semantic/capability cells、每组同预算；新能力至少进入 2 个此前不可达 cells，且 baseline 可达 cells 的 hard-gate 通过率不下降超过预先冻结余量；随机审计永久剪枝 100%。不是“proposal 数更多”。 | proposer 崩溃归一化为 `program_exception`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；硬门失败 `numerical_fail/physical_fail`；剪枝错误 `program_exception`；单 candidate 失败不能删 grammar。 | frozen campaign manifest、seed/shard plan、proposal/compiled/failure/archive counts、capability delta、prune certificates、merge audit。 |
| **B11 独立重放** / R07,R10 | 新鲜工作区/环境、source/data/provider/checker versions、完整 command list、candidate/mission/scenario/solver hashes；独立执行者或独立 process。 | outputs、exit codes、hash joins、scientific classification、artifact completeness、乱序/恢复一致性。 | 建议 2 次 fresh replay；required artifact completeness `100%`，identity/hash join `100%`；数值量在冻结 tolerance 内，terminal classification 相同。B11 只证明可复现性，不自动提供独立物理验证、双代码验证或 validation credit；恢复不得重复计 evidence。 | 缺 artifact/中断 `human_interruption/not_executed/unknown`；输出差异超门 `numerical_fail`；provider match 属于 `{no_match, out_of_domain, invalid_signature}` 时 `resolution=terminal_deferred`；不能用旧 run 的 exit 代替新 replay。 | environment lock、commands、stdout/stderr、exit files、hash manifest、independent checker report、replay receipt。 |
| **B12 周期正净输出** / R05,R07,R10 | candidate-bound whole-device full-cycle input/output energy，供能、回流、转换、维护、停机、燃料和不确定性；冻结系统边界和周期。 | `E_net=E_out-E_in`、每项 ledger、scenario distribution/model discrepancy、lower confidence bound、重复计量检查。 | 建议正式门为预注册发电运行/统计完整周期在 uncertainty/model-discrepancy 协议下 `lower_bound(E_net)>0`；所有 required 场景各自适用门通过，故障按安全停机/恢复义务并把损失计入周期，不能删故障成本或要求每一瞬间净正。具体置信水平、周期和 margin 先冻结。设计目标/conditional range 不充作 net output。 | solver/ledger 不闭合 `numerical_fail`；完整适用账本为负 `physical_fail`；缺项/无分布 `physical_status=unknown; resolution=terminal_deferred`；不确定性缺失 `unknown`。 | immutable whole-device energy ledger、scenario inputs、uncertainty/discrepancy report、independent recomputation、authority envelope。 |
| **B13 独立原创性** / R09 | candidate 的 canonical structural/mechanism/behavior descriptors、时间戳、内部 archive、外部文献/专利查询范围和独立审查人。 | 数学等价、结构差异、行为差异、机制差异、外部相似项、披露日期和覆盖范围。 | 建议至少两名独立审查人、两类外部来源、查询式/日期/覆盖范围可复放；不得预设“hash 唯一=原创”。阈值由 R09 campaign 冻结，结果不能反向改搜索门。 | 查询缺失 `resolution=terminal_deferred`；等价未识别 `program_exception`；外部证据冲突 `unknown`；不能因低 fidelity 行为差异宣布原创。 | descriptor/hash archive、等价证明、查询日志/来源 hash、独立 review reports、scope-limited originality envelope。 |

### 4.1 阈值冻结与数据切分规则

正式 campaign 运行前，主线程必须把上述建议值转换成版本化 `acceptance_protocol`，同时冻结单位、归一化尺度、rounding、随机种子、grid、solver iteration/stop rules、provider registry、独立性分组和 checker 版本。任何看过结果后的阈值调整都必须创建新 protocol/campaign，并保留旧结果。

校准数据、调参数据、validation 数据和 held-out 数据必须以不可重叠的 artifact ID、shot、scenario 或 topology identity 切分；同源派生量也不能跨 split 泄漏。`held_out_combination` 要在组合层去重，不能只改变一列数值就宣称独立组合。

## 5. R01–R10 父目标关账矩阵

R01–R10 是完整父目标，不因 UP 阶段变小。下表状态是历史快照（as-of 2026-09-13），仅保留证据上限和失败语义；它不是 2026-09-20 的实时状态。当前状态由本目录 `21_next_execution_batches.md`、`16_execution_work_orders.md` 和 `task_manifest.json` 的新鲜证据决定；`partial`、`screen_only`、`deferred`、`unsupported` 都不是 accepted。

| ID | 必须保留的父目标 | 必需证据组合 | 历史状态（as-of 2026-09-13） | 终局接受条件 |
|---|---|---|---|---|
| **R01** | 同一通用生产链处理已知参考与新候选，标签、family 和 benchmark 身份不能改变物理路由。 | B00、B04、B05、B10、B11；三 Genome refs/hash、candidate/solver identity join。 | `partial`：有 candidate binding、capability routing 和局部执行。 | UP0–UP3 统一链通过；label-erasure、非法拒绝、拓扑转移、fresh replay 全通过。 |
| **R02** | ITER 等参考装置可表示并真正反解，包括描述往返、隐藏参数恢复、多起点、可识别性和 held-out 预测。 | B03、B06、B07；真实 source provenance、完整 interior/boundary basis 和独立留出。 | `not_implemented_in_current_chain`；现有 W03/W09–W21 仍有 source/basis/provider/held-out gap。 | ITER 设计参考的三层 Genome 反演/同链设计一致性通过；另有至少一个独立实测参考通过适用 B03/B07B、可识别性与盲留出门。输出须含 G1/G2/G3，ITER 设计目标不得替代实验 validation。 |
| **R03** | 物理方程、空间/时间、守恒、边界、闭合、稳定性、损失和输运达到声明深度。 | B01、B02、B05、B06、B08；candidate-bound provider 与独立数值 checker。 | `failed_current_attempt`：W24 四 case exit 4/iteration_limit；N1 有负观察阶。 | 所有 required cases 收敛，守恒和网格/时间阶通过，模型闭合无 unresolved deferred。 |
| **R04** | 整机工程与控制：线圈/电路、供能、热/结构/材料、环境、故障、启停、燃料循环和控制反馈。 | B08、B12；工程 scenario、fault traces、供能/热/结构 ledger。 | `partial_local_subsystem`：仅有拾取工程子系统。 | 全部 required engineering scenarios candidate-bound、可重放、边界闭合且 margins 通过。 |
| **R05** | 全周期站级正净输出，边界冻结、无漏项无重复计能，并在不确定性/模型差异下成立。 | B08、B12、B11；独立 energy ledger 与 lower-bound 计算。 | `not_implemented_in_current_chain`；没有 complete candidate-bound plant power producer。 | 预注册发电运行/统计周期的净输出保守下界为正，全部 required 场景通过各自适用门；故障场景按安全停机/恢复等义务检验且其损失纳入完整周期，不要求每一故障瞬间净输出为正。不能用 ITER Q=10 或 conditional range 代替。 |
| **R06** | 独立物理验证与 UQ：独立数据/solver、校准验证隔离、误差、适用域、模型差异和传播。 | B01、B03、B06、B07、B08、B11；independence groups 与 validation artifacts。 | `missing_data_and_providers`；当前 physical validation 未执行，软件 benchmark credit 为 0。 | 独立来源/代码/数据实际执行且适用；不确定性和 discrepancy 可追溯传播。 |
| **R07** | 高等级 evidence 和 final authority 可达；screen/missing/cross-boundary/replay 不能冒充。 | B00、B04、B06、B11、B12、B13；`FinalWholeDeviceAuthorityV4` envelope。 | `not_implemented_in_current_chain`；现有路径有意保持 screen/deferred 上限。 | 所有 required obligations 有适用 evidence，无 unresolved deferred；authority 独立审计并写 claim ceiling。 |
| **R08** | G1/G2/G3 开放式发现闭环：真实后代→物理求解→档案回写→后续提议，多机制/几何/实现变化可达，失败可恢复。 | B05、B09、B10、B11；multi-emitter、failure frontier、archive、resume receipts。 | `partial_queue_only`；W23 是 G1 两代 0D screen，W24 是一对 G2 screen，仍 `R08_accepted=false`。 | UP3–UP5 形成跨 Genome 的真实闭环；搜索能力增量和独立 replay 通过，非单一局部赢家。 |
| **R09** | 独立原创性证据：数学等价、结构/行为/机制差异及文献/专利检索、日期和覆盖范围。 | B09、B10、B13；独立审查和 scope-limited novelty records。 | `not_implemented_in_current_chain`；没有完整 external prior-art/originality pipeline。 | B13 在已声明 scope 内通过；内部唯一哈希只能是线索，不能自动给出外部原创性。 |
| **R10** | 新鲜环境可复现交付与原始目标关账，至少一个新候选同时通过 R03–R09。 | B00–B13 中适用项、B11、final authority、代码/数据/审查包。 | `not_achieved`；没有同时通过 final hard gates 的新候选。 | fresh replay 成功、证据完整、authority 发 L4（或更高）scope 的 `credible_within_scope`；否则保留 `platform_ready` 与 `discovery_goal_achieved` 的分离状态。 |

## 当前应用

UP1约定软件门、UP2-00/B00 F0–F5及B04 N01–N10各5变体=50项正式覆盖的合格结果保留，未受影响行为复用；真实改变则按受影响门回归。原验收条款在manifest/16逐项保留，组件通过不关闭UP2整体。

Q1_8当前scaledmax1.5257218976168253e-5按用户决定接受当前状态；原1e-6 numerical_fail保留，不写原门通过，完整FD/完整新进程复放未执行。

resource_interruption须保留独立执行分类；完整资源证明不足时零信用，不以成功子进程、cleanup或结果相同补齐。物理适用域、来源、完整R/J/solver及独立验证齐备后才能授对应范围。终局候选0，父Goal仍暂停。
