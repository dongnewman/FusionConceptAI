# 11 物理编译、离散组装与耦合层执行规划

> 文档性质：可执行设计与验收合同，不是现有能力声明。本文只定义本阶段的新增工作；工单 ID、依赖、预算和排队由主线程的 `16_execution_work_orders.md` 与 `task_manifest.json` 维护，本文不另立任务 ID。记录日期：2026-09-14。

## 1. 目标与不可越过的边界

目标是把三个已经类型化的 Genome 编译成可审计的物理问题，再把问题分成四个明确层次：

```text
typed Genome / hypergraph
  -> equation IR
  -> weak residual IR
  -> discrete residual / sparsity / transfer
  -> solver plan / candidate-bound execution
```

编译器可以自研语义、单位、边界、闭合、守恒和离散装配层；线性/非线性/ODE-DAE 迭代、预条件、稀疏因子分解等成熟算法通过 capability 适配器复用。复用算法不等于复用某个装置家族的隐藏模型。FUSE 在此只作为融合设计集成框架参考；适用模型、输入合同和适用域决定它能覆盖的范围。它不能替代任意 PDE，也不负责本项目的证据绑定，不能把 FreeGS 或 DESC 的适用域扩展成通用求解器。FreeGS、DESC 必须保留专用适配器和明确的适用性记录。

必须突破三项当前限制：

1. `Compiler.jl` 不能只生成 structural screen obligation；它必须能把算子和状态编译为可检查的 equation IR。
2. `FieldProgramEvaluation.jl` 不能把 exact AST 永久限制为标量、静态、单 chart 和七个基础 opcode；导数算子必须经过类型、坐标、度量和 function-space 合同后进入 weak residual。
3. `FieldResidualPipeline.jl` 不能把生产物理路径固定为六节点 `LAPLACE(u)-2f`；该表达式保留为 manufactured control，生产路径要接受变系数、各向异性、界面、时间项和多场耦合。

以下事实是当前源码审计结果，不能被规划文字改写成“已完成”。

## 2. 当前实现证据与明确缺口

### 2.1 抽象编译器

现有 `src/RuntimeV4/Compiler.jl` 的 `_runtime_edge_obligation`（约第 20–75 行）只检查端口、统一空间维度、时间语义和单根 operator 名称；非零空间维度会因没有显式坐标声明而留下 `required_coordinate_declaration`，随后返回 `required_physical_capability:<operator>`。`_runtime_structural_obligation`（约第 77–82 行）固定发出 `:structural_screen` / `typed_graph` capability。`compile_candidate`（约第 90–150 行）确实保存未解析 nonterminal、图声明和 capability obligation，但没有 equation、weak residual、离散系统或 solver plan。

这证明了 typed AST/hypergraph 已被使用，也证明了现阶段是前缀一致性编译，不是物理编译。后续实现必须保留 `CompiledCandidatePrefixV4` 的可追溯字段，不可将新编译器偷偷替换成 family 模板。

### 2.2 G2 程序求值

`src/RuntimeV4/FieldProgramEvaluation.jl` 当前 `_FIELD_EVAL_SUPPORTED_OPS` 只有 `IDENTITY, ADD, SUB, NEG, SCALAR_MUL, SCALAR_DIV, DOT`；`GRAD, DIV_OP, CURL, LAPLACE, DT` 在 `_FIELD_EVAL_DEFERRED_OPS` 中。`compile_field_evaluation_plan`（约第 298–390 行）把多 chart、chart transition、周期网格、非静态根、非标量根和导数算子写入 deferred gap；`_field_eval_node`（约第 492–545 行）只执行上述封闭 opcode。因此现在可以得到候选绑定的 screen-level sampled values，不能把它叫作坐标映射、度量或 PDE 离散。

### 2.3 D4.1 manufactured residual

`src/RuntimeV4/FieldResidualPipeline.jl` 的 `_frp_validate_manufactured_g2`（约第 293–331 行）要求精确的七节点、两根 AST；这是 G2 的双根 artifact AST。`_frp_exact_static_field_constraint`（约第 334–365 行）要求的是另一个 G1 residual AST，精确六节点 `LAPLACE(u)-2f`，并非前一个 AST 的节点计数或同一对象；`u/f` 无量纲静态 scalar3D、系数为 `2.0 m^-2`。`compile_field_residual_plan`（约第 369–420 行）明确把证据类固定为 `:manufactured_control`。`_frp_execute_input`（约第 490–495 行）组装 `assemble_field_residual_kernel` 并求解已固定的结构化网格内核，`field_residual_provider`（约第 522–536 行）声明的是 `:structured_field_residual_solve`，authority 仍为 `screen_only`。

该链路有价值：它提供 exact AST、source/boundary artifact hash、单次 solver-input 执行、二阶 manufactured 收敛门和负控基线。但它不是通用 equation compiler，也不能作为任意候选的物理证明。

### 2.4 空间多区域与工程侧限制

`src/RuntimeV4/SpatialMultiRegionV4.jl` 的 `spatial_multiregion_declaration_v4`（约第 22–53 行）当前固定为两个理想静态 MHD 区域、`div(T)=source`、固定 `rho=.5` 接口、外边界 `rho=1`、Q1/三维柱坐标采样、四个状态 `B_R,B_phi,B_Z,p` 和固定 flux scenario。`build_spatial_mesh_v4`（约第 63–111 行）使用预设区域和网格拓扑；`assemble_spatial_system_v4`（约第 667–735 行）装配压力/应力、`divB`、界面和外边界残差。它是候选绑定的空间 MHD slice，不是可任意替换材料/方程的通用离散后端。

`SpatialPickupEngineeringV4.jl` 的固定拾取线圈/RL 是第 12 份文档的输入边界；本规划只要求它以 capability 形式被编译和耦合，不能把它当作任意逆设计模型。

### 2.5 当前已存在的可复核入口

以下是源码或 test manifest 中已存在的入口，现阶段可用于回归和边界核验：

```text
julia --startup-file=no --project=. test/runtime_v4_field_residual_composition_tests.jl
julia --startup-file=no --project=. test/runtime_v4_field_residual_numerics_tests.jl
julia --startup-file=no --project=. test/runtime_v4_spatial_multiregion_tests.jl
julia --startup-file=no --project=. test/runtime_v4_spatial_pickup_engineering_tests.jl
julia --startup-file=no --project=. test/runtime_v4_conservative_multiregion_execution_tests.jl
julia --startup-file=no --project=. scripts/run_v4_spatial_chain.jl <new-run-directory>
```

最后一个入口实际支持的参数由脚本首行/usage 和 `--g2-child --resume --upstream-only --physics-only` 分支决定；新工单执行前必须重新读脚本核准参数、环境和输出位置。本文不假装任何 `compile_equation_ir`、`assemble_coupled_system` 或新 runner 已存在；这些名称只作为拟建 API 记号。

## 3. 目标输入、输出和合法性边界

### 3.1 输入合同

`PhysicsCompilationRequestV4`（拟建）必须包含：

| 输入 | 必须内容 | 缺失时处理 |
|---|---|---|
| 三 Genome 引用 | URI、版本、schema/canonicalization hash、compatibility profile | `terminal_deferred` |
| candidate/prefix | `candidate_hash`、`prefix_hash`、三图、source/sink ledger | 不得按 family 默认补齐 |
| equation declarations | 状态、算子、方程量词、源/汇、守恒账户 | 缺一项则 `required_obligation` |
| geometry/chart | 区域、接口方向、坐标、metric、映射、function space | 坐标/度量缺失不得离散 |
| boundary/initial/closure | Dirichlet/Neumann/Robin/periodic/interface、初值、代数约束 | 不完整则 `terminal_deferred` |
| units/scales | 每个 field、coefficient、flux、time、residual 的单位和参考尺度 | 单位不可推断时 fail-closed |
| scenario | operating、fault、parameter interval、随机种子/确定性规则 | 不得选择性遗漏场景 |
| backend capability | 完整能力签名和适用域 | 无唯一匹配时 deferred |

设计 alternative 是存在量词；声明 scope 内的运行/扰动/故障 scenario 是全称量词。equation IR 必须记录两类量词，否则不得进入 UP3。

### 3.2 四层 IR 与输出

1. **Equation IR**：规范化变量、算子树、强形式/约束、单位、时间语义、边界和 conservation account。每个项带 `term_id`、上游 gene refs、输入/输出 function space、坐标 chart 和 operator capability。
2. **WeakResidual IR**：测试函数、积分域、分部积分方向、自然/本质边界、接口双侧 trace、源/汇符号、时间质量项、非线性/参数依赖。弱形式不允许通过“删掉奇异或冗余方程”来获得可解；零空间必须显式记录 gauge、pinning、integral constraint 或 nullspace basis。
3. **DiscreteResidual**：mesh/basis/quadrature、自由度 ordering、局部 element block、global assembly map、interface transfer、conservative flux map、残差 block/unit/scale、Jacobian sparsity 和离散 nullspace。
4. **SolverPlan**：完整输入 hash、provider manifest、线性/非线性/DAE 算法、预条件、容差、停止条件、restart/checkpoint、artifact contract、失败分类和证据 ceiling。

每层都必须有独立 canonical hash 和 provenance；下层 hash 必须绑定上层 hash，不能以一个最终 blob 取代四层审计。

### 3.3 后端按能力签名路由

路由 key 必须至少包括：operator set、完整 physical state set、source/target function spaces、维度/坐标、boundary/interface relation、time semantics、required output、evidence level、input schema hash、backend revision、applicability bounds。`family`、display label、parent、候选序号、请求顺序、shard 顺序和 benchmark flag 不能影响匹配、hash、容差或结论。空 axis 非法，不能解释为 wildcard。

适配器分三类：

- `native_compiler_backend`：本项目 equation/weak/discrete/solver plan 的完整生产路径；
- `mature_algorithm_backend`：Gridap 等弱形式/有限元装配，PETSc 等 KSP/SNES/TS/TAO 线性、非线性、ODE/DAE 算法；本项目仍拥有输入和残差语义；
- `domain_adapter_backend`：FreeGS/DESC 的特定 equilibrium/coil/geometry 能力，必须输出适用域和不支持项，不能伪装成 general PDE。

## 4. UP0–UP6 统一执行路线

### UP0：基线合同冻结

**输入/边界。** 只读当前 `00_normative_contracts...`、`01_candidate...`、三 Genome 文档、源码和 test manifest；冻结状态词、hash domain、evidence ceiling、R01–R10 和 L4 可信计数（当前仍为 0）。不得改代码、不得重计算。

**有限工单步骤。**

1. 记录 HEAD、dirty diff、三个源码文件 hash 和已存在 runner/test 路径。
2. 从每个 Genome 列出 state/operator/space/boundary/source/actuator 消费者，生成只读 obligation table。
3. 将 `LAPLACE(u)-2f` 标记 `manufactured_control_only`，将 Spatial MHD、pickup RL 标记 domain-specific slice。
4. 预注册单位表、归一化公式、容差、负控和 scenario quantifier；每个阈值写版本和理由。

**验收协议。** 清单能从每个 obligation 追到 gene、现有源码或明确 `proposed`；标签擦除后基线 hash 不变；任何未执行项都是 `unknown/deferred`。负控：删一个 boundary、改一个 unit、把 `family` 改名，均不得得到相同的“通过”证据。UP0 只产合同和审计 artifact，不产生物理通过。

### UP1：G1/G2/G3 合同与最小可执行组件

**输入/边界。** 仍保留现有 typed AST/hypergraph 和 exact manufactured tests；新增最小组件只接受一个标量变系数扩散 equation、一个二维/三维 chart、一个 Dirichlet 或 Neumann 边界，以及一个明确 source。暂不做多场和 inverse。

**拟建落点。** 在 `src/RuntimeV4/` 新建/扩展按层命名的模块（例如 `EquationIRV4.jl`、`WeakResidualIRV4.jl`、`DiscreteResidualV4.jl`、`SolverPlanV4.jl`）；禁止把这些拟建文件名当作已存在路径。现有 `Compiler.jl` 只增加调用/记录接口；现有 manufactured 模块保持原语义。

**有限步骤。**

1. 定义 sealed typed records：Term、StateSlot、FunctionSpace、BoundaryCondition、ConservationAccount、UnitExpr、NullspaceRecord。
2. 从一个 G1 `TypedASTProgramV1` 或 G2 `TypedFieldProgramGeneV1` 编译 equation IR；对 `GRAD/DIV_OP/LAPLACE/DT` 先产生 typed obligation，只有 chart/metric/space 完整才降到可执行 operator。
3. 实现 source/flux/boundary 单位检查和方程项维度检查。
4. 生成最小 manufactured weak residual 与一个真实变系数扩散输入；将 provider manifest 与 capability 签名绑定。
5. 对 AST 节点顺序、区域 ID、family/label 擦除做 canonicalization 回归。

**验收。** 通过 existing exact tests 后，新增 focused test（名称可由主线程工单决定，如 `runtime_v4_equation_ir_minimal_tests.jl`，在文件存在前不得执行该命令）必须证明：系数变化会改 solver input hash；只有在 UP0 明确声明规范单位转换模型、换算方向和舍入容差时，同一 equation 的单位变换才可 canonicalize 一致，当前实现不得声称自动支持任意等价单位；边界缺失变 deferred；零空间不被静默删方程。数值门槛先按 UP0 预注册：manufactured relative L2/L∞ 阈值写入 protocol；只在预注册阈值、网格序列和参考解均存在时判 pass。负控包括在正扩散 profile 下的负扩散系数、未声明/错维度 source、冲突的重复 boundary、欠约束纯 Neumann；显式零源另设合法正例；预期分别为 compile rejection 或 explicit nullspace/deferred。

### UP2：声明编译、空间物化、拓扑闭合、耦合与 backend 适配

以下五个子节严格对应 `16_execution_work_orders.md` 的 UP2-01–UP2-05；它们完成编译和模块适配，不提前宣称 UP3 的完整组合或 UP4 的逆 realization。

#### UP2-01：声明驱动的物理方程编译

**输入/边界。** UP1-04 通过的 typed bundle、算子/closure 注册和现有 Compiler/FieldProgramEvaluation/FieldResidualPipeline；支持变系数/各向异性扩散、时间项和多场项的声明 lowering，固定六节点公式仍只作 manufactured fixture。

**有限步骤。**

1. 将状态/参数/端口与 region 绑定为 Equation IR，输出所有闭合、边界和 source/sink 义务。
2. 逐算子 lowering，保留 strong→weak 的符号、单位、function-space 和 boundary ownership；导数没有 chart/metric/space 时只产生 obligation/deferred。
3. 生成结构稀疏关系及 AD/解析/数值导数适用性元数据；未经声明的替代闭合必须拒绝。

**验收。** 至少一个不等于现有 fixture 的合法组合能编成真实 residual；缺算子执行器、闭合或边界明确延期；不得按 name/family/ID 路由。

#### UP2-02：空间物化、离散组装与一般入口

**输入/边界。** Equation IR、G2 域/场空间、离散 profile、边界和材料数据。现有 `SpatialMultiRegionV4.jl` 只作为兼容 slice。

**有限步骤。**

1. 实现几何→网格/基空间→弱式或数值通量的可验证装配，每个 element/face 保存 local residual/Jacobian、DOF、quadrature、orientation 和 provenance。
2. 以完整 capability 合法性取代 `_smr_declaration` 的固定模型身份守卫；guard 只能保护既有 fixture，替换必须与真实执行支持同批落地。
3. 支持不修改源码的候选数据输入；非匹配网格使用显式 mortar/projection 或有限体积通量并记录投影误差。

**验收。** 变系数、边界或区域连接变化无需源码分支；MMS 解误差、残差、积分守恒、网格/时间细化分别通过冻结门。

#### UP2-03：拓扑传递与外部区域闭合

**输入/边界。** 网格/场空间、G1 守恒账户、接口条件、外域/源/回流声明。

**有限步骤。**

1. 实现重网格、分裂/合并后的守恒投影，约束 `divB`、正性和规范条件；不能同时满足时返回定位诊断。
2. 实现一条明确适用的外域路径，如真空/导体域加远场截断；源和电路回流必须由 G3 明确给出。
3. 对静态设计拓扑编辑与物理拓扑事件分别验证，禁止把数值重映射当磁重联物理。

**验收。** 转移前后每个 account 的总量差、局部误差和接口 defect 通过冻结门；远场截断/外域细化敏感性通过；删除外域或漏回流的负控必须延期或拒绝。

#### UP2-04：耦合求解、约束与集成

**输入/边界。** 离散 residual/稀疏结构、端口依赖、初值、约束和停滞诊断；这一步只建立可供 UP3 消费的耦合入口。

**有限步骤。**

1. 依据依赖图识别强耦合块/DAE 和约束，选择 monolithic 或 partitioned 求解接口。
2. 处理规范零空间、初值一致性、约束方向和全局化；采用 augmented constraint 或 solver nullspace API，不删除方程。
3. 生成 SolverPlan，记录 provider、容差、同步点、transfer、守恒 defect、停止条件和失败分类；顺序后处理不能标为 coupled closure。

**验收。** 故意错误 Jacobian、缺初值、停滞和约束失败能被正确识别；所有强耦合残差和守恒同时过门的完整组合验收留到 UP3。

#### UP2-05：成熟物理模块及 backend 能力登记

**输入/边界。** 已运行的组件核、成熟库官方文档/锁定版本和完整 capability schema。

**有限步骤。**

1. 逐项登记扩散、电磁、电路、热、弹性 provider 的输入输出、边界、时间、材料、单位和误差范围。
2. FreeGS/DESC 只接各自适用域的专用 adapter；FUSE 只作融合设计集成参考，不作为任意拓扑总入口。
3. 对 transport/kinetic/burn/loss 等缺模块列出模型、接口、数据/资源和 UP6 拆单触发条件。

**验收。** 每个 claimed provider 有组件执行和负例；仅安装包或 `bridge_ready` 不构成 provider 证据；删除 provider 后路由返回具体缺口，不降级到隐藏族模板。

### UP3-03：可选的受验证基降维

UP3-03 是 `16_execution_work_orders.md` 中的可选加速项，不阻塞 UP3 主组合或后续 UP4。输入已经收敛的高维系统、训练/验证/留出样本、约束和量纲；先审计规范零空间和可识别性，再选择 POD/谱基/约束投影，保存基构建范围、守恒保留、误差估计保守性、OOD 和拓扑变化重建条件。必须与未参与构基的高维解比较；新拓扑或超域时回退 full model。ROM 不能填补闭合/provider 缺口，也不能单独授予最终证据。

### UP4：为逆 realization 提供闭环编译与重算接口

UP4 的逆设计、源硬件、热结构控制回代、真实参考逆恢复和集成验收由 [12](12_composition_and_inverse_realization.md) 的 UP4-01–UP4-04 负责；本节只规定 11 提供的编译与重算接口，不把物理编译器本身写成逆解器。

**有限步骤。**

1. 接收 12 输出的 realization alternative、source/return/material/control 声明和受影响的 G1/G2/G3 refs，重新生成 Equation IR、WeakResidual IR、DiscreteResidual 和 SolverPlan。
2. 对 geometry、topology、material、driver 或 time-path 的物理声明变化生成新的 `physical_subject_hash`；普通 Newton 状态、迭代轨迹和输出只生成绑定该 subject 的 state/iteration/artifact hash。
3. 重新编译并重算 field、circuit、thermal、structure 依赖图；保留 transfer、守恒、零空间、单位和失败分类，供 12 的 UP4-04 汇总。
4. 不支持的 intermediate provider、外域或回流保持 `terminal_deferred`；不以已有 manufactured 或旧 candidate artifact 填补新闭环。

**验收。** 仅当 12 的 UP4-01–04 提供真实 source realization、工程回代、参考逆恢复（若声明）和 fresh replay receipt 后，才能把本接口的输出加入 R03/R04/R06–R10 证据；11 本身不产生终局 authority。

### UP5：条件 e-graph 与广搜索

**输入/边界。** 仅允许在 UP0–UP4 已注册 typed operators、equation rewrite、units、function spaces、boundary/closure 和 capability manifest 上搜索。当前 e-graph/有界整程序原型只算搜索机制；没有生产物理搜索入口，不能报告 discovery。

**有限步骤。**

1. 为每条 rewrite 注册条件：类型相容、单位保持、边界语义保持、守恒账户保持、nullspace 不变或显式更新。
2. e-class analysis 只做等价压缩和 cost/novelty 预算；任何可能改变离散或物理含义的 rewrite 必须产生新的 genome/subject hash。
3. 对每个后代重新执行 UP1–UP4 compile/route/execute；不复用发生物理改变候选的旧 evidence。
4. 先小预算验证“无预写组合”可被发现和拒绝，再扩展 QD/MCTS/生成式 proposal；模型输出永远是 proposal，不写 stage outcome。

**验收。** 同一声明下的代数等价表达合并；改变边界/材料/拓扑不合并；搜索标签擦除后结果不变；同一 attempt 内每个正式 solver input 最多执行一次，fresh replay 即使输入相同也必须生成新的 attempt/receipt。负控：允许单位破坏的 rewrite、删除约束的 rewrite、family-specific rewrite、把预测分数写入 evidence，均必须被拒绝或显式标为 proposal-only。

### UP6：R01–R10 整装

整装必须按主线程 `16_execution_work_orders.md` 依赖运行：R01 为通用链/身份与标签擦除，R02 为参考表示与隐参逆恢复，R03 为物理方程/空间时间/守恒/边界/闭合/稳定性/损失/输运，R04 为整机工程与控制，R05 为全周期站级正净输出，R06 为独立物理验证与 UQ，R07 为高等级 evidence 与 final authority，R08 为 G1/G2/G3 开放式发现闭环，R09 为独立原创性，R10 为 fresh replay、交付和原始目标关账。任何软件 milestone、runner exit 0、文档完成或有限搜索没有合格候选，都不能关闭父目标。L4 可信计数在获得对应独立证据前保持 0。

## 5. 单位归一化、零空间与预注册门

### 5.1 单位规则

每个 term 保存原单位和 canonical SI 单位；归一化只作用于 solver conditioning，不修改 physical quantity。以参考量 (L_0,T_0,U_0) 和各 state 的 (S_q) 生成 dimensionless variable，并保存 forward/inverse transform hash。残差 row scale 只能是单位一致的正尺度；scale 变更必须改 numerical configuration hash。严禁用一个无量纲 `norm` 掩盖 Pa、T、Wb、A、J、N/m³ 的混合。

最低检查：

```text
term_output_unit == declared_equation_unit
flux_left_unit == flux_right_unit
interface_sign(right) == -interface_sign(left)
source/sink_account_sum 的单位一致
每个 scale > 0 且 finite
inverse(normalize(x)) 在预注册 round-trip 容差内
```

### 5.2 零空间和方程计数

编译器先列所有未知、方程、边界、接口、global constraint 和 gauge；然后给出 rank/nullspace 预期。纯 Neumann、压力 gauge、磁势 gauge 或周期问题必须显式 `NullspaceRecord`，由 augmented system、pinning（需合同允许）或 PETSc nullspace 处理。任何“为了让矩阵可逆而删除一行”的实现都是拒收；删除必须有 proof authority 证明该行是严格重复且保留等价约束的合同。

### 5.3 预注册阈值表

阈值由 UP0 artifact 冻结，执行后不能按结果回填：

| 门 | 记录 | 通过条件 |
|---|---|---|
| 编译 | schema/type/unit/boundary | 全部 required closure；否则 deferred |
| 数值 | residual、linear/nonlinear status、finite | finite、停止条件满足、无 silent NaN |
| 守恒 | 每个 account、接口两侧、全局 source/sink | 按 scenario protocol 的绝对+相对预算 |
| 磁散度 | cell/face/global `divB` 或等价约束 | 按 field unit 的预注册预算 |
| 离散 | refinement order/GCI 或 manufactured error | 至少预注册级数和 order 区间 |
| 耦合 | transfer defect、interface jump、fixed-point/monolithic residual | 全部在合同预算内 |
| 证据 | input/provider/backend/code/artifact hash | 可 replay 且 identity exact |

门值必须带单位、网格/时间级别、backend revision、置信/不确定性解释和适用域。没有测量/验证数据时只能给 numerical screen claim ceiling。

## 6. 失败处置与状态映射

- contract/schema/type/unit/closure 缺失：`terminal_deferred`，保留 candidate prefix 和 unresolved obligation。
- 中间组合 provider 无匹配、歧义、out-of-domain：`terminal_deferred`，不能写 `physical_fail`；`unsupported` 只允许保留既有终端 provider 的原生结果。新 terminal 的最终 `unsupported` 只能由 `FinalWholeDeviceAuthority` 判定，任何 capability 只能提供诊断/义务，不能自行授予最终 `unsupported`，也不能用来掩盖中间 provider 缺失。
- 非有限数、矩阵 factorization 失败、迭代停滞：`numerical_fail` 或 `unknown`，保留完整 input、attempt、环境和部分 artifact；不得自动改容差重跑并覆盖原 receipt。
- 守恒/边界/磁散度门失败时先按缺陷来源分类：离散误差、装配/传递错误或数值协议未满足为 `numerical_fail`，编译/实现语义错误为 `program_exception`；仅在适用域已证明且数值协议满足后，声明的硬物理量仍违门时才为 `physical_fail`。保留 residual localization，不能由代理分数补偿。
- 预注册的独立验证缺失：`unknown`/evidence ceiling 降低；不能变成 `credible_within_scope`。
- 组合发现未实现 provider：保留 dormant/frontier candidate，等待新 provider；不得丢弃或永久剪枝。

`execute-once` 只限制同一 attempt 内对完整 `solver_input_hash` 的缓存复用；cache hit 可以复用该 attempt 的 evidence ref，但不能冒充独立执行。fresh 独立 replay 即使输入 hash 相同，也必须新建 run/attempt 和 evidence receipt，并记录新的环境、backend 和输出核对结果。失败处置不能修改历史 sealed artifact 或 dirty worktree 中非本工单文件。

## 7. 最终交付检查

本文件的编制交付只记录规划、当前源码证据、拟建模块的 file ownership、每个 UP 阶段的有限步骤和依赖、预注册门表、负控矩阵、失败状态映射以及官方/项目来源；这段是 archive 性质的历史说明，不是后续执行禁令。编制本身未实施代码；后续按 `16_execution_work_orders.md` 的授权工单和 `14_agent_orchestration.md` 的文件归属、复核与重计算规则实际写代码、测试、运行，并在执行后更新相应 artifact/receipt。拟建路径只有在真实代码、命令、exit code 和证据满足对应工单后才能改写为 actual。

## 8. 来源与适用性（核验日期 2026-09-14）

- 以下官方页面于 2026-09-14 访问；软件版本、commit 和本机 backend manifest 尚未冻结，必须在 UP0 重新锁定后才能形成可复现证据。版本未锁定前仅作适用性参考。
- [Gridap.jl ODE/弱形式文档](https://gridap.github.io/Gridap.jl/stable/modules/ODEs/)：核验有限元空间、弱形式和 transient operator 的接口思想；适合作为成熟弱形式/装配后端参考，不证明本项目物理模型已实现。
- [Gridap tutorials：advection-diffusion](https://gridap.github.io/Tutorials/stable/pages/t010_advection_diffusion/)：核验强形式到积分弱形式的基本范式；适用于 UP1–UP2 的数值语义参考。
- [PETSc SNES](https://petsc.org/release/manualpages/SNES/SNES/) 与 [KSP](https://petsc.org/release/manualpages/KSP/KSP/)：核验非线性和线性 solver capability；适用于算法复用，不替代 equation/units/closure 合同。
- [PETSc TS](https://petsc.org/release/manualpages/TS/TS/)：核验 ODE/DAE 时间积分能力；适用于 transient backend 路由。
- [DESC Equilibrium API](https://desc-docs.readthedocs.io/en/stable/_api/equilibrium/desc.equilibrium.Equilibrium.html)：核验 DESC Equilibrium 的 equilibrium/profile/nearby solve 适用对象；只可通过专用 adapter 使用。
- [FreeGS documentation](https://freegs.readthedocs.io/en/stable/)：核验 FreeGS 的 equilibrium/coil/optimisation 专用范围；不能作为通用多拓扑 PDE backend。
- 本仓库 [00 共同合同](00_normative_contracts_and_state_model.md)、[01 候选集成](01_candidate_integration_and_abstract_compilation.md)、[05 realization](05_realization_and_independent_physics_execution.md)：项目内规范性来源，优先级高于外部算法文档。
