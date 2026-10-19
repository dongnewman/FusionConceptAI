# 物理编译、离散与全局闭合：剩余能力

UP2整体HOLD。热/原生网格及若干global组件已有限验收，历史运行只从证据读取；当前五项接口、来源、责任和验收消费者见[16](16_execution_work_orders.md)，批次见[21](21_next_execution_batches.md)。

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

## 当前接线和剩余能力

`CandidateCoupledPhysicsV4`的真实state/geometry/current/pressure/outer callbacks → `InHouseCoupledMHDGlobalSolveV1::assemble_coupled_mhd_global_v1` → 原native消费者。pressure/current/B_out/K_outer/return五项逐键缺口仍HOLD；来源、单位、方向、积分和DOF不能只放在不被R/J消费的evidence对象里。

UP2-01～05保留一般多场/时间项、复杂空间/拓扑传递、外域、强耦合及适用输运/燃烧/稳定性/损失等能力；安装或局部MMS只算准备/限定数值范围。Q1_8当前数值状态已用户接受，不再要求继续降残差；原1e-6失败留存，完整验证与通用求解能力另记。

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

实现前明确真实输入→映射→物理律→R/J→消费者。短检查只覆盖本次最可能失败处；原完整A/B之前必须具体失败/修复收敛，沿用现有runner与原覆盖/阈值。
