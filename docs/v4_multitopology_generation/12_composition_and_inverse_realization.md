# 12 物理模块组合与源硬件逆向实现闭环规划

> 文档性质：可执行设计与验收合同，不是“已实现逆设计”声明。任务 ID、依赖、预算和并行关系由主线程 `16_execution_work_orders.md` 与 `task_manifest.json` 持有；本文不另立任务 ID。记录日期：2026-09-14。

## 1. 目的和结论边界

本阶段将“物理场 → 工程源硬件 → 供电/热/材料/结构 → 回代物理场”做成候选绑定的闭环。它解决的是 `realization`：在 G3 已声明的组件和资源网络中，寻找满足场目标与工程约束的有限 alternative。它不声称从一个真实参考装置恢复所有隐含参数，也不把一个静态磁场值转换成凭空存在的 EMF。

必须同时满足四个原则：

1. 组合按完整 capability signature 路由，不按 device family、候选名、benchmark 标签或历史装置身份特判。
2. 所有模块的输入输出、单位、方向、守恒账户和适用域可审计；一项缺失就 deferred。
3. 逆设计的目标至少包括目标场误差、供电资源、热、材料和结构约束，并在同一候选状态上迭代回代；只拟合磁场不算工程实现。
4. “realization 成功”与“真实参考装置隐参 inverse recovery”分开。参考装置隐参、测量校准和制造/实验资格缺失时，claim ceiling 不能超过 numerical/engineering screen。

FUSE 在此只作为融合设计集成框架参考；具体适用模型、输入合同和适用域决定范围。它不是任意拓扑万能 PDE 替代，也不负责本项目的证据绑定。FreeGS 与 DESC 保留各自适用域的专用 adapter；现有固定拾取线圈/RL 仅可作为其声明 scope 内的 engineering slice。

## 2. 现实现证据审计

### 2.1 空间物理上游

`src/RuntimeV4/SpatialMultiRegionV4.jl` 的 `spatial_multiregion_declaration_v4`（约第 22–53 行）固定声明两个 `static_ideal_mhd` region、`B_R/B_phi/B_Z/p` 四状态、`div(T)=source`、`rho=.5` continuous interface、`rho=1` traction/normal-B boundary、预设 coarse/fine spaces、继承 toroidal flux 和 `external_currents_and_outer_sheet_unknown`。它是有明确限制的 candidate-bound static MHD slice。

`build_spatial_mesh_v4`（约第 63–111 行）预设 cylindrical Q1 mesh、region assignment 和 face roles；`spatial_field_v4`（约第 641–651 行）由 Q1 basis 计算 `B_xyz`、`J_xyz`、`gradp`、stress、`divB`；`assemble_spatial_system_v4`（约第 667–735 行）装配体积分、interface/exterior traction、normal-B 和 total flux 行。它能作为“场状态→电流分布”的输入切片，但不能证明外部线圈、电源或结构闭合。

### 2.2 现有 pickup/RL 工程 slice

`src/RuntimeV4/SpatialPickupEngineeringV4.jl` 的 declaration（约第 32–70 行）固定 circular finite disk、turns、wire/material/RL 参数、静态 plasma flux contribution、stationary coil、`induced_emf_V=0`，并明确 `external_coils=:unknown`、`outer_sheet_current=:unknown`、`current_closure=:must_be_propagated`。`spatial_pickup_transfer_v4`（约第 171–203 行）用 Biot–Savart 与数学 unit-current reciprocity 计算有限孔径磁通；reciprocity 只是数值互检，不是实际驱动。

`spatial_exact_rl_segment_v4` 和 `spatial_pickup_exact_response_v4`（约第 206–315 行）对固定电阻、固定电感、固定 cadence 和 prescribed fractional flux ramp 计算分段指数 RL 流、能量恒等式、short/dump 事件。该输入是预设磁通 ramp，不是由 plasma dynamics 求出的 EMF；静态场本身没有 `dPhi/dt`，因此不能白给感应电压。`_spe_owned_declaration`（约第 399–405 行）还要求恰好一个且 hash 等于默认 declaration，证明当前逆实现入口具有固定模型身份限制。

### 2.3 现有验证边界

当前 pickup case 的 `_spe_case_computation`（约第 434–460 行）把状态输入检查、磁通 transfer 和 conditional RL response 串起来，但最终 `status` 在成功数值路径仍为 `:unsupported`，`physical_upstream_valid=false`，`total_external_field=false`、`physical_validation=:unsupported`。因此已有测试可以证明 deterministic replay、互易误差和理想电路能量账本，不能证明硬件可制造、供电可用、热结构合格或真实装置参数恢复。

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

每个数值必须能回溯到 G1/G2/G3 gene、mission、显式 alternative 或测量 artifact；每个 solver input 绑定 candidate, scenario, backend, numerical configuration 和 code hash。design alternative 是存在量词；operating/fault scenario 是全称量词。不得只保留最好场景。

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

## 5. UP0–UP6 执行路线

### UP0：闭环合同和证据界限

**步骤。** 读取并冻结 00、05、09、三 Genome 文档、当前 Spatial MHD/pickup 源码与 tests；登记 dirty worktree。列出目标场、源硬件、供电、热、材料、结构、回流和每条 transfer。将固定 pickup 的 `induced_emf_V=0` 和 prescribed ramp 分开记录。预注册 objective、约束、单位、scenario 全称量词、alternative 存在量词、失败状态和证据 ceiling。

**验收。** 每个 closure obligation 都有 upstream ref 或 `required/deferred`；删除 external coil 或 return path 时不能通过。只产只读合同；不改代码、不重计算。

### UP1：组件合同和组件核（对应 UP1-01–UP1-04）

**目标输入。** 一个 field source、一个 finite aperture、一个 declared circuit、一个 thermal loss proxy、一个 structural constraint。此阶段只冻结接口、单位和独立组件核，不进行完整组合验收。

**拟建落点。** 在 `src/RuntimeV4/` 增加 typed records（如 `CompositionContractsV4.jl`、`PowerCircuitCapabilityV4.jl`、`ThermalCapabilityV4.jl`、`StructuralCapabilityV4.jl`，均为拟建）；扩展现有 `SpatialPickupEngineeringV4.jl` 时保留 fixed declaration 和 hash guard 作为 legacy fixture adapter。严禁把拟建文件当作当前存在命令或模块。

**步骤。**

1. 为每个 provider 定义 input/output physical state、space、units、boundary、time semantics、applicability 和 evidence scope。
2. 将 current pickup transfer 的 flux/reciprocity 接口封装为 capability；保留 plasma-current-only scope。
3. 对 circuit 写逐节点 KCL/KVL/RL 合同；对 thermal 定义 heat source/temperature units；对 structure 定义 stress/displacement/clearance units。
4. 运行每个模块的 manufactured/analytic test、负例和单位 round-trip；Genome 迁移和入口集成只消费已冻结合同。

**验收与负控。** 现有 pickup/spatial tests 只能验证 legacy slice；新增测试必须证明 flux reciprocity、逐节点 KCL、RL identity、单位和 hash/replay。静态 flux 直接填 EMF、断开回流、passive profile 中的负电阻/负电感、材料缺失、错法向分别触发时间导数义务、deferred 或 compile rejection。主动等效元件必须另有声明 source/control/energy 语义的 active profile；缺少该 profile 时为 `terminal_deferred`。

### UP2：编译接口与模块适配（对应 UP2-01–UP2-05；不做完整组合验收）

**输入/边界。** 消费 11 的 UP2-05 provider manifest、G1/G2/G3 合同、field/source/circuit/thermal/structure 的独立组件核。此阶段建立 typed transfer 和适配器，不把相邻模块顺序串联写成闭环，也不宣称 UP3 组合通过。

**有限步骤。**

1. 为 field source、finite aperture、circuit、thermal、material/structure 定义输入输出 state、function space、单位、时间和 boundary adapter。
2. 将 `B/J/flux`、coil/source geometry、`Phi_linkage`、KCL/KVL/RL、heat source、stress/displacement 映射到组合合同；静态 field path 的 EMF 保持 0，ramp/motion/driver 必须声明 derivative source。
3. 对 plasma、external coil、wall/sheet、return contributions 建立 provenance 和独立 transfer hash；未闭合 external coil/return 只留下 obligation。
4. 按完整 capability signature 路由成熟 provider；FreeGS/DESC 保持专用适用域，FUSE 仅作融合设计集成参考。
5. 运行标签擦除、单位错误、接口方向和缺 provider 负控；保留 `terminal_deferred`，不得因单组件 solver exit 0 生成组合证据。

**验收。** 每个 adapter 能通过独立单位、有限值、方向、scope 和 replay 检查；不要求或声称 field-circuit-thermal-structure 的联合残差同时通过，完整组合验收进入 UP3。

### UP3：声明范围内合法成熟组合自动执行（对应 UP3-01–UP3-03）

**输入/边界。** UP2 已登记且实际可执行的 field、source、circuit、thermal、material、structure、control provider；组合由 dependency graph 和 typed port 生成，从变系数扩散/电磁-电路逐步扩展到热和结构。未匹配 provider 不能进入 solver。

UP3-01/UP3-02 负责真实组合矩阵与留出/反证测试；可选的 UP3-03 受验证 ROM 由 11 的对应小节执行，不阻塞主组合，也不能替代完整模型复验。

**有限步骤。**

1. 以 typed `CompositionGraphV4` 检查每条 state edge 的单位、空间、时间、source/sink account 和适用域；按依赖图选择 monolithic 或 partitioned solver。
2. 计算 total field 时分离 plasma、external coil、wall/sheet、return contributions；对每个电路节点单独装配 KCL residual，global sum 只作诊断。
3. 计算功率与热源时区分 `J·E` 功率交换、`q_J=J²/σ` 电阻性热、Poynting flux、`ΔE_storage`、机械功和 declared export，避免重复计账。
4. 联合执行 field/source/circuit/thermal/material/structure/control；partitioned 方案记录迭代顺序、transfer、同步点、relaxation 和守恒 defect，monolithic 方案记录 block/Jacobian/nullspace。
5. 对 nominal、fault、cooling、tolerance 和启动/停机 scenario 全部执行；每次改变物理设计或参数声明才生成新 `physical_subject_hash`，普通状态/迭代只生成绑定该 subject 的 state/iteration/artifact hash。

**验收。** 每个已声明组合的目标场、逐节点 KCL/KVL、field/coupling/thermal/structural residual、source/return conservation、`ΔE_storage` ledger 和接口门同时通过；拆除任意反馈边、冷却、电源限制或回流的负控必须暴露失败。无匹配或超域为 `terminal_deferred`，不以 solver convergence 覆盖缺口。

### UP4：逆设计、源硬件与完整热结构控制回代（对应 UP4-01–UP4-04）

UP4 严格对应 `16_execution_work_orders.md` 的 UP4-01–UP4-04。此阶段仍是 scope 内 numerical/engineering screen；真实参考装置隐参恢复必须有独立来源和留出数据。

#### UP4-01：源与硬件的逆向 realization

定义 coil shape/turn/current/driver/return/material 等可制造设计变量、目标场误差、供电资源和约束。采用受约束多起点优化，报告不可达残差、局部极小、不可识别方向、Jacobian rank/condition 和非唯一解；将实际 source 替代目标 source 后重新编译并重算主物理。静态场不产生无时变依据的 EMF。

#### UP4-02：热、材料、结构与控制回代

把 Lorentz force、pressure、thermal expansion、support reaction、供电损耗和控制保护接入 dependency graph；重新求 thermal/structure/control，并把温度、材料、位移、变形和故障状态回传 source/field。所有 required scenarios 必须达到同时 residual 和硬约束门。

#### UP4-03：真实参考表示与隐参逆恢复

仅消费有 provenance 的真实参考/实验/设计数据；先 round-trip 已知属性，再用多起点、噪声/缺测协议和 held-out observations 反演隐藏参数。记录 rank、condition、posterior/区间、可辨识性和非唯一性；自生成 MMS 不得称真实参考。

#### UP4-04：逆实现闭环集成验收

串联需求→设计→实际源→主物理→热/结构/控制反馈，检查 candidate/scenario/input/provider hash 贯通、每节点 KCL、全账本和 fresh replay。闭环通过不等于 R05 净输出或 R07 authority 通过；缺 transport/burn/完整整装义务仍保持开放。

### UP5：条件 e-graph 与扩大搜索（对应 UP5-01–UP5-03）

**输入/边界。** 只消费 UP4 已验证的 operator、组合、source grammar、rewrite side conditions 和 evidence/cache 身份。ROM 属于 11 的可选 UP3-03；UP5 不用 ROM 或代理分数替代 full model。

**有限步骤。**

1. 接入条件 e-graph，逐条验证 units、rank、boundary/time semantics、conservation、effect 和 applicability 条件；未满足条件不得合并。
2. 丰富 G1 operator/closure、G2 domain/interface/geometry、G3 source/material/control 的 typed edits；物理设计变化重建 `physical_subject_hash`，普通状态变化不重建 Genome identity。
3. 将 residual localization、constraint sensitivity、实现误差和热/供能瓶颈作为 proposal feedback；缺 provider 单列工作，不永久剪枝。
4. 实现可恢复 QD/MCTS/多 emitter 和 failure frontier；有界比较 campaign 中保持相同 seed/budget/cost，并把 proposal 与 evidence authority 隔离。

**验收与负控。** 每条 rewrite 可独立 replay，有限预算未饱和标 `incomplete`；标签、候选特判、单位破坏、删除约束、family-specific rewrite、把 objective/预测分数写入 evidence 均拒绝或标 proposal-only。ROM OOD、拓扑变化复用旧 basis 等问题按 11 的 UP3-03 规则处理。

### UP6：R01–R10 整装与真实参考装置区分

整装沿主线程依赖完成 R01–R10：R01 为通用链、标签擦除和身份；R02 为真实参考表示与隐参逆恢复；R03 为物理方程、空间/时间、守恒、边界、闭合、稳定性、损失和输运；R04 为整机工程与控制；R05 为全周期站级正净输出；R06 为独立物理验证与 UQ；R07 为高等级 evidence 与 final authority；R08 为 G1/G2/G3 开放式发现闭环；R09 为独立原创性证据；R10 为 fresh replay、交付和原始目标关账。R03–R10 不能合并成笼统的“物理/工程验证”阶段。

若只有 numerical inverse candidate，没有测量、制造、校准或独立 hardware evidence，最多是 scope 内 numerical/engineering screen；不得写“真实参考装置已恢复”“已制造”“已测得净电”。不论组合器、ROM、优化器或文档是否完成，L4 可信计数保持 0，直到独立验收账本真实满足。

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

## 8. 可执行验收协议

以下命令是当前仓库已经存在、可作为基线回归的入口；新逆实现 runner/test 生成前不能假装存在：

```text
julia --startup-file=no --project=. test/runtime_v4_spatial_multiregion_tests.jl
julia --startup-file=no --project=. test/runtime_v4_spatial_pickup_engineering_tests.jl
julia --startup-file=no --project=. test/runtime_v4_conservative_multiregion_execution_tests.jl
julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl <new-run-directory>
```

执行前应读对应 test 和 runner 的 usage、输入 fixture、环境要求及输出目录；`<new-run-directory>` 是占位符，不是已存在目录。拟建验收协议按以下顺序落地：

1. 现有 fixture replay：candidate/context/declaration/artifact hash 完全匹配，确认既有 fixed slice 未被改写。
2. 独立模块测试：field/current/flux、circuit、thermal、structure 各自通过 units、finite、negative controls。
3. 未预写组合测试：至少一条变系数/新拓扑组合不走 candidate-specific branch，已声明支持的留出组合必须经 capability router 实际执行并通过数值/守恒门；声明域外的组合准确延期，但不计作组合执行验收通过。
4. 闭环测试：同一 frozen subject 在至少 nominal、fault、tolerance scenarios 中生成完整 ledger、iteration receipt 和 failure state。
5. 标签擦除与置换测试：删 label/family/parent/benchmark 标记；仅 display metadata 变化时物理 hash/routing/evidence 不变，物理内容变化时 hash 必变。
6. 独立 replay：新环境重放同一 solver input，确认 artifact、code/backend manifest、numerical config 和结果 hash 可核对；同一 attempt 只可复用缓存，fresh replay 必须生成新的 run/attempt/evidence receipt，不能把 cache hit 算作独立证据。
7. R01–R10 ledger audit：仅主线程 authority 可将 stage evidence 组装为终局分类；本模块不产生终局 `credible_within_scope`。

## 9. 交付边界

本文件的编制交付只记录规划、当前源码证据、拟建模块的 file ownership、有限工单步骤、预注册门、负控和失败状态；这段是 archive 性质的历史说明，不是后续执行禁令。编制本身未实施代码；后续按 `16_execution_work_orders.md` 的授权工单和 `14_agent_orchestration.md` 的文件归属、复核与重计算规则实际写代码、测试、运行，并在执行后更新相应 artifact/receipt。拟建路径只有在真实代码、命令、exit code 和证据满足对应工单后才能改写为 actual。

## 10. 来源与适用性（核验日期 2026-09-14）

- 以下官方页面于 2026-09-14 访问；软件版本、commit 和本机 backend manifest 尚未冻结，必须在 UP0 重新锁定后才能形成可复现证据。版本未锁定前仅作适用性参考。
- [Gridap.jl ODE/弱形式文档](https://gridap.github.io/Gridap.jl/stable/modules/ODEs/)：适用于热/扩散等有限元弱形式和 transient operator 的成熟后端参考；不提供本项目的 geometry、units、closure 或 inverse authority。
- [PETSc SNES](https://petsc.org/release/manualpages/SNES/SNES/)、[KSP](https://petsc.org/release/manualpages/KSP/KSP/) 与 [TS](https://petsc.org/release/manualpages/TS/TS/)：适用于非线性、线性和 ODE/DAE 算法复用；必须由完整 capability 和 SolverPlan 约束，不能按装置家族路由。
- [DESC Equilibrium API](https://desc-docs.readthedocs.io/en/stable/_api/equilibrium/desc.equilibrium.Equilibrium.html)：适用于具有 DESC equilibrium/profile/nearby-equilibrium 语义的 adapter；不适用于任意多拓扑、材料、供电、热结构闭环。
- [FreeGS documentation](https://freegs.readthedocs.io/en/stable/)：适用于 FreeGS 的 equilibrium/coil/optimisation 专用 adapter；不能作为通用 PDE 或逆硬件证明。
- 本仓库 [00 共同合同](00_normative_contracts_and_state_model.md)、[05 realization 与独立物理解算](05_realization_and_independent_physics_execution.md)、[09 evidence/authority roadmap](09_evidence_authority_campaign_and_v4_roadmap.md)：v4 状态、hash、适用性、证据 ceiling 与 R01–R10 的规范性来源。
- 本仓库 `src/RuntimeV4/SpatialMultiRegionV4.jl`、`src/RuntimeV4/SpatialPickupEngineeringV4.jl`：当前实现边界的直接源码证据；行号可能随后续实现变化，执行工单应按当前 checkout 重新核对。
