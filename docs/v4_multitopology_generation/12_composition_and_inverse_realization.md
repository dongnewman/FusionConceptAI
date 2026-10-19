# 组合与逆实现：当前合同和剩余路线

UP3仅有限组合screen已通过，完整原消费者/17Q1、留出与反馈断边仍HOLD。UP4固定电流forward配对仅screen；44/44optimizer/handback的原运行资源失败，无新增正式信用。真实MAST输入、三Genome反演与工程反馈未完成。当前接口/责任见[16](16_execution_work_orders.md)，下一有界门见[21](21_next_execution_batches.md)。

## 3. 组合执行合同

### 3.1 组合输入

拟建 `CompositionRequestV4` 必须包含：

| 输入 | 内容 | 必须边界 |
|---|---|---|
| physical subject | exact candidate/prefix/genome bundle/mission hash | 禁止 family 默认替换 |
| target field | 空间、时间、分量、测量/目标场误差定义 | 必须注明 target 是数值目标还是测量数据 |
| source candidates | G3 已声明 coil/current/driver/return path alternatives | 未声明组件不得发明 |
| resource networks | 电源、电流、电压、回流、开关、保护和接口 | account 必须闭合或显式 deferred |
| thermal/material/structure | material law、loss、temperature、stress、displacement、clearance | 缺材料/边界不能用零值补齐 |
| scenarios | operating、fault、ramp、cooling、manufacturing tolerances | 进入 scope 的 scenario 全部评估 |
| backend manifests | 完整 operator/state/space/time/boundary capability | 唯一匹配要求 |
| budgets | field/energy/thermal/stress/conservation/iteration limits | UP0 预注册且 hash-bound |

### 3.2 组合输出

`ExecutableRealizationBundleV4`（拟建）至少输出：

```text
physical_subject_hash
design_alternative_id / scenario_ids
field_solution_refs and field_error_with_units
component_geometry/material/current/voltage records
source and return closure ledger
thermal loss/source/temperature records
structural stress/displacement/clearance records
coupling transfer maps and hashes
iteration history and convergence reason
constraint residuals and active-set record
provider closure and applicability records
solver_input_hashes / artifact refs / evidence ceiling
```

每个数值必须能回溯到 G1/G2/G3 gene、mission、显式 alternative 或测量 artifact；每个 solver input 绑定 candidate, scenario, backend, numerical configuration 和 code hash。design alternative 是存在量词；operating/fault scenario 是全称量词。不得只保留最好场景。历史 `docs/implementation/` 只在工单明示时提供 as-of 历史事实和原始收据；不得用作当前实现指导、排期或规范来源，不改变本章合同，也不把局部结果自动接入生产链。

### 3.3 能力签名与模块边界

组合器应按以下完整签名选择 provider：

```text
operator + complete physical states
source/target function spaces + dimensions + coordinates
boundary/interface relation + time semantics
required output + evidence level
input schema hash + backend revision + applicability bounds
```

建议的 capability 模块边界如下：

| 模块 | 输出 | 当前状态 |
|---|---|---|
| Field equilibrium / MHD | B、J、p、divB、force/flux residual | SpatialMultiRegion 是 domain slice；待通用接口 |
| Electromagnetic source/coil | coil geometry、J/K、A/B、flux linkage、external field | Biot–Savart pickup 只覆盖 declared plasma/current scope |
| Circuit/power | V/I、EMF、RL/driver/protection trajectory、energy ledger | 固定 pickup RL 已有；一般 supply/return 待建 |
| Thermal | Joule/eddy/radiative loss、temperature field、cooling boundary | 待建，不能用电路能量自动替代热模型 |
| Material/structure | stress、strain、displacement、yield/fatigue/clearance | 待建，材料与边界必须来源可核验 |
| Coupling/iteration | transfer、residual、Jacobian/response、stopping | 待建；不能用顺序后处理冒充 coupled closure |

## 4. 逆实现问题的数学合同

### 4.1 目标和约束

对设计变量 (z)（线圈位置/形状/匝数、材料、导体截面、供电参数、回流路径、冷却参数等）和状态 (x)（场、电流、温度、位移）定义：

\[
\min_{z,x}\; J = w_B\|W_B(B(x,z)-B^*)\|^2 + w_I\|W_I(I-I^*)\|^2
 + w_E\,E_{source}+w_T\,\Phi_T+w_S\,\Phi_S+w_C\,\Phi_{complexity},
\]

其中每个权重、单位转换和目标来源在 UP0 固定。约束包括：

```text
R_field(x,z) = 0                  # PDE/equilibrium/weak residual
R_circuit(x,z) = 0                # KCL/KVL/RL/driver/protection
R_thermal(x,z) = 0                # loss + heat transfer + cooling
R_structure(x,z) = 0              # stress/strain/displacement equilibrium
R_interface(x,z) = 0              # B/flux/traction/thermal/current transfer
R_conservation(x,z) = 0           # source-sink ledgers
g_bounds(z,x) <= 0                # voltage/current/temp/stress/clearance/manufacture
```

静态场的约束只提供 `B`、`J`、flux linkage 等静态量；若要得到 EMF，必须有真实时间变化的 flux linkage、coil motion、driver excitation 或明确 external field ramp。任何 `EMF=-dPhi/dt` 都要记录 derivative source、time grid、sign convention 和 uncertainty；静态 `Phi` 不可自动变成非零 EMF。

### 4.2 外部线圈和回流闭合

外部线圈、电源、回流域和边界电流必须形成闭合 network。至少验证：

```text
for every circuit node n: R_KCL,n = 0 with units A
global sum(KCL residuals) is diagnostic only; it cannot replace per-node gates
driver current enters declared conductor and returns through declared path
surface/volume current boundary is closed or its reservoir is declared
external field contribution is separated from plasma contribution
net flux/energy/source account has no unowned sink/source
```

若 `external_coils`、`outer_sheet_current` 或 return path 是 unknown，则 inverse result 只能 `terminal_deferred`；不得将内部 plasma-current flux 当 total external field。

### 4.3 参考装置真实反演合同：资料→观测→未知量→Genome→正向→held-out

参考反演的输入不是一个装置名或一份已拟合模板，而是可审计的数据包：来源文件或数据库标识及 SHA、许可和 provenance、坐标/时间/单位、诊断响应或观测算子 `H`、测量误差与缺测 mask、已知输入 `x`、校准观测 `y_cal`、独立 validation/held-out 观测 `y_val`，以及待恢复的未知量 `theta`。未知量可以包含机制参数、边界/几何参数、场基系数、源电流、材料或控制参数，但每一项都必须声明所属 G1/G2/G3 层、适用域、先验/边界和是否可识别。缺少真实来源、观测定义、未知量边界或独立留出时，任务保持 `terminal_deferred`。

反演先由 `G1/G2/G3(theta)` 生成合法 Genome bundle，再由与新候选相同的通用编译和评价入口 `F` 物化场、几何、源和控制；`H` 只负责把物理输出映射到装置实际观测。优化可写成：

```text
min_theta  (H(F(G1(theta), G2(theta), G3(theta); x)) - y_cal)' * Sigma_cal^-1
           * (H(F(G1(theta), G2(theta), G3(theta); x)) - y_cal)
           + declared_regularization(theta)
subject to typed units, physical closure, realization and engineering constraints.
```

接受顺序固定为：表示往返（资料→Genome→物化→可观测量）；解析/MMS 或合成隐藏真值的实现检查，并明确标为 synthetic recovery；真实观测的多起点反演，记录失败解、Jacobian rank/condition、等价类或非唯一性；最后用训练未访问的 shot/channel/time/geometry/topology 做 held-out forward prediction。held-out 只能消费已冻结的 `theta`/Genome 和同一生产链，不能把观测答案放入 seed、cache、basis、初值或 benchmark-only 构造器。一个可识别的局部参数子集只能关闭相应子范围，不能宣布整机 R02 已完成。

### 4.4 参考资料与能力域的分层及就绪门

参考对象按资料和能力就绪状态区分；名称只作为 provenance 的人类标签，不得进入 provider 路由、分支条件或验收豁免。

| 参考层 | 可用于的合同 | 数据/能力就绪门 | 可声明上限 |
|---|---|---|---|
| ITER 设计 | 几何、线圈/电流、平衡、加热和单位的表示往返与前向设计一致性 | 设计资料 provenance、坐标/单位/版本、可物化 G1/G2/G3 字段；公开 Q/功率目标不能冒充实测观测或净电 | 设计参考与 synthetic/forward screen；不能独立关闭真实观测反演、R05 或 L5 |
| MAST 实测 | 真实观测反演、校准/validation/held-out 和诊断响应 | 原始 shot/通道、诊断定义、误差/缺测、已知输入、独立留出和许可可复核；任何缺口逐项 deferred | 只有 B03/B07B 所需数据和同链 forward、识别、held-out 全齐时，才可产生 R02 范围内 credit |
| HELIOTRON 数值/非轴对称 | 几何/基函数/非轴对称数值复放与 capability 验证 | 明确 solver/backend 版本、几何/边界/基函数输入和适用域；同一家族生成与检查同一状态不算实验独立性 | numerical cross-check 或 declared-scope provider evidence；不能替代实测参考或独立代码/数据 |
| C-2W pending | 记录待获取的数据和能力缺口 | source/diagnostic/geometry/solver 入口和许可尚未齐全时保持 `required + terminal_deferred`；不得以网页、代理或 anchor copy 填空 | pending capability；不能进入 R02 accepted 或作为其他装置的替代证据 |

其中“数据就绪”必须同时包括真实输入、观测、观测算子、误差/缺测、未知量定义、split manifest 和可执行 provider；只有资料页、参数表、局部 basis、组件合同或一次局部数值运行，都不构成就绪。参考层可共用规则执行器，但 mission、适用 obligations 和 claim ceiling 由 manifest 明确声明；不得硬编码装置名条件路由。

### 4.5 局部成果接入完整能力的集成门

任何局部成果（组件、cross-mesh transfer、诊断、ROM、inverse optimizer、engineering bridge 或搜索 emitter）只有同时满足以下五项，才可写入 integrated execution 或为上游任务提供正式输入：

1. 有明确的消费者入口：生产链中的函数/API、工作单节点或 manifest edge，以及其 input/output schema、单位、时间/边界语义和 capability signature。
2. 有实际调用：由真实入口读取该成果并留下 command、source/data/provider hash、solver input hash、process/verification exit 和 artifact receipt；静态 import、合同文件或孤立 focused test 不算调用。
3. 有真实输入：来自声明资料、观测、Genome、candidate/scenario 或可复核 provider；不能用 placeholder、固定 anchor、装置名分支或只复制参考输出。
4. 有下游闭环：成果输出进入下游物理/工程/控制/诊断节点，产生 residual、守恒/资源账本、反馈或 held-out prediction，并按 `physical_fail`、`numerical_fail`、`program_exception`、`unknown`、`terminal_deferred` 分类。
5. 有独立复放：新鲜进程或独立 checker 重读同一输入和中间 hash，复现结果/分类；复放只能证明可复现性，不自动提供物理独立性。

缺少任一项只能标 `contract_only`、`screen_only`、`prepared_not_executed` 或 `terminal_deferred`，不得用 component-level pass 覆盖完整能力缺口。对参考反演，集成门的最小闭环是“参考资料→观测→未知量→G1/G2/G3→同生产链 forward→held-out→独立复放”；对新候选，还必须继续通过 source/engineering/whole-device 适用门。

## 当前剩余执行

- UP3准备/耗时：修现有Profile导出并实测source_records/T1，一次真实coupled residual/step及受影响反馈FD，再完整组合/留出/断边/复放；复用仍适用R14结果。
- UP4硬件：实际受约束优化→G3电流/线圈handback→同候选同电流forward→热/结构/供能反馈；资源短检先通过。
- UP4参考：第一方PF101→938带符号段/匝数映射、Thomson校准/通道/误差定义先GO；同链calibration/identifiability/heldout及新进程复放，不以默认0/制造解/已拟合参考输出替代。
- 用户已选择当前解析候选采用理想轴对称周期等离子体，并显式声明/验证LCFS J·n=0；实现与原消费者尚未通过，软件模型不提供实测MAST权威。

## 6. 单位、守恒和预注册门

### 6.1 量纲归一化

所有模块输入输出同时保存原单位、canonical SI 单位、参考尺度和 transform hash。推荐尺度包括 (B_0,[T])、(L_0,[m])、(I_0,[A])、(V_0,[V])、(T_0,[K])、σ₀ `[Pa]`、(P_0,[W])、Φ₀ `[Wb]`。归一化只改善条件数，不改变物理 ledger。必须验证 `denormalize(normalize(x))` 在 UP0 round-trip 容差内。

### 6.2 必须闭合的账本

| 账本 | 最低核验 |
|---|---|
| 磁通/场 | plasma、external coil、sheet/wall、return contribution 不重复，界面法向和单位一致 |
| 电荷/电流 | 每个 circuit node 的 KCL 残差分别达门；供电、导体、回流和边界 reservoir 闭合；全局残差和仅作诊断 |
| 能量 | 在声明时间窗内，driver input = `ΔE_storage` + 电阻性 Joule/thermal loss + Poynting/机械功/declared export + residual；各项有独立 owner，不能把 `J·E` 与 `I²R` 重复计热 |
| 热 | 每个热源有空间/时间 owner；温度边界与散热出口有 owner |
| 力/结构 | Lorentz/pressure/thermal loads 与 support reaction、stress/clearance 对应 |
| 数值 | residual、Jacobian/iteration、transfer defect、rank/nullspace 可 replay |

缺少 owner 的项不能用 0 填充；应 `required_obligation` 或 `terminal_deferred`。

### 6.3 预注册阈值

UP0 冻结每一门的绝对/相对阈值、单位、网格/时间级别、scenario、backend revision、统计/不确定性处理和 claim ceiling：field target error、field residual、flux/EMF transfer、KCL/KVL、energy defect、thermal residual/max temperature、structural residual/max stress/displacement/clearance、coupled fixed-point residual/state change、deterministic replay/hash identity。执行后禁止因失败而放宽门。

## 7. 失败处置

- 缺 G3 组件、材料、边界、回流、external coil 或 measurable target：`terminal_deferred`，保存未闭合 obligation。
- 中间 capability 无匹配/歧义/超域：`terminal_deferred`；不写物理失败。`unsupported` 仅可保留既有终端 provider 的原生结果。新 terminal 的最终 `unsupported` 只能由 `FinalWholeDeviceAuthority` 判定，任何 capability 只能提供诊断/义务，不能自行授予最终 `unsupported`，也不能把中间 provider 缺失标成 unsupported。
- solver NaN、rank failure、非收敛、artifact/hash replay 不一致：`numerical_fail` 或 `unknown`，保留完整 attempt 和输入；重跑生成新 evidence。
- 已声明 field/energy/thermal/structural hard gate 失败时先按缺陷来源分类：离散误差、装配/传递错误或数值协议未满足为 `numerical_fail`，编译/实现语义错误为 `program_exception`；仅在适用域已证明且数值协议满足后，声明的硬物理量仍违门时才为 `physical_fail`。不得由场误差或 cost 补偿。
- 只通过 nominal 而 fault/cooling/tolerance scenario 未执行：`unknown`/`terminal_deferred`，不得 promotion。
- ROM OOD、basis 不适用于新拓扑、参数回代超出训练包：退回 full model 或 deferred；ROM 结果不能作为独立验证。
- 数值 inverse 找到一组可行参数但真实参考装置缺 metadata/measurement：`credible_within_scope` 不可用，保持 numerical/engineering screen ceiling；rank/condition、多起点、held-out 和非唯一性证据缺失时也不得宣称唯一恢复。

历史 artifact、sealed run 和 dirty worktree 非本工单文件不得覆盖；每次组合图、物理设计或参数声明变更都要产生新的 candidate/subject/solver hash，普通状态、Newton iteration 和收敛轨迹只产生绑定该 subject 的 state/iteration/artifact hash。

完整适用工程约束、账本、UQ与相同生产forward仍是退出条件；原阈值和R01–R10不变。

已决模型（2026-10-09直接用户回复）：当前解析候选采用理想轴对称周期等离子体，显式声明并验证LCFS无法向电流。GO仍要求实际J/法向/切面/积分/DOF、守恒与全局R/J、改动FD和原消费者。若声明改变候选输入则正常生成新候选，不改旧payload/身份或历史失败；既有产物只复用其仍适用范围。MAST来源、工程回流网络和终局标准不因此通过。
