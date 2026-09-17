# v3 可复用实现审查与迁移顺序

## 1. 审查目的与边界

本审查用于减少 FusionConceptAI v4 后续整链实现中的重复开发。审查对象是旧实现目录
`outputs/fusion_concept_ai/`，目标目录是独立的新仓库 `FusionConceptAI/`。

本审查只判定旧代码是否可作为算法、适配器、测试或设计参考，不给旧运行结果追加
物理、工程、VVUQ 或可信装置结论。v4 的三种 Genome 文档和公共合同仍是唯一上游；
任何旧类型、旧状态或旧结果都必须经过新 typed AST、operator hypergraph、provider、
solver-input 和 RuntimeEvidence 合同重新绑定。

审查日期：2026-09-08。

## 2. 资产盘点

排除 `.vendor/`、虚拟环境、运行产物和临时目录后，旧目录包含：

| 资产 | 数量 | 初步价值 |
|---|---:|---|
| `src/**/*.jl` | 322 | 数值内核、物理编译器、provider、VVUQ、搜索和整装逻辑 |
| `src/adapters/*.jl` | 35 | 外部求解器和低/中保真模型适配经验 |
| `src/search/*.jl` | 91 | QD、Pareto、typed grammar、分片恢复和证据调度 |
| `test/**/*.jl` | 161 | sentinel、负控制、收敛、provider gap 和整装回归语料 |
| `scripts/**/*.jl` | 309 | 可复现入口、批处理、审计和报告生成参考 |

结论：可复用资产很多，但“模块级参考价值”远高于“整文件直接复制价值”。大多数旧模块
使用 `Dict{String,Any}`、字符串状态、旧 candidate identity 或旧证据结构。直接 include
旧模块会重新引入 v4 已经消除的兼容性、权限和路由问题。

## 3. 复用分级

### A 类：优先抽取纯算法

这类代码可以复用数学公式、离散方法、排序/合并算法或确定性 I/O 逻辑，但输入输出要
改成 v4 的具体类型，不能返回旧 `Dict` 状态包。

| 旧实现 | 可复用内容 | v4 处理方式 |
|---|---|---|
| `src/solvers/generic_ode_dae_event_adapter.jl` | RK4、解析对照、事件前后分段控制 | D1 已有新实现；旧代码仅保留为独立回归 oracle，不回迁旧接口 |
| `src/conservation_ledger_compiler.jl` | 守恒量分类、内部交换抵消、余额审计 | 映射到 G1 state/edge/ledger occurrence，输出受封守恒 receipt |
| `src/numerical_verification.jl` | 解析解、制造解、步长加密和检测下限思想 | 拆分数值误差、测量不确定性和模型差异，禁止合成一个泛化 `pass` |
| `src/search/recoverable_sharded_execution_v19.jl` | 确定性分片、原子提交、内容寻址、重试和恢复等价 | 改为 immutable manifest、Digest256、严格 shard merge；删除可变 Dict authority |
| `src/search/pareto_behavior_archive_v1.jl` | cell 内 Pareto/保留策略 | 只在 frozen scope 和 hard-gate survivor 上运行 |

### B 类：保留算法主体，重写合同外壳

这类模块包含较多可用物理或执行逻辑，但旧请求、结果、路由和证据结构不能保留。

| 能力域 | 旧实现候选 | 必须重写的边界 |
|---|---|---|
| capability routing | `operator_capability_router_v89.jl`、`operator_provider_registry_v94.jl`、`capability_solver_portfolio_v90.jl` | 使用完整 `CapabilitySignatureV4` 精确匹配；禁止 family/name/ID 路由；no-match 只产生 gap/deferred |
| 多区域残差 | `graph_residual_assembler_v94.jl`、`multiregion_residual_compiler_v89.jl`、`multiregion_interface_assembly_v93.jl` | 从 G1/G2 typed declarations 编译 block row、接口、单位和 ownership，不接受位置 fallback |
| 耦合执行 | `coupled_execution.jl`、`multiregion_nonlinear_runtime_v90.jl` | 保留数值算法和守恒检查；用 candidate-bound subject/input/evidence 替换旧 Dict 输出 |
| 高保真组合 | `high_fidelity_solver_portfolio_v92.jl`、`whole_device_provider_dag_v107.jl` | DAG 必须由 obligations 编译；availability、startup、convergence、physical pass 分开 |
| numerical VVUQ | `candidate_vvuq_runtime_v87.jl`、`generic_vvuq_runtime_v94.jl`、`physical_vvuq_runtime_v96.jl` | 绑定同一 subject、场景、离散协议、norm 和 independence group；制造解不计 validation credit |
| 工程闭合 | `magnet_engineering_compiler.jl`、`material_engineering_provider_v109.jl`、`channel_thermal_hydraulics_provider_v117.jl`、`dynamic_fault_provider_v108.jl` | 全部输入来自 G3/mission typed producers；缺材料、载荷或边界时保留 unknown/deferred |
| 整装执行 | `whole_device_preflight_v104.jl`、`whole_device_assembly_generator_v105.jl`、`whole_device_provider_dag_v107.jl` | admission 与 post-run closure 分开；部分 stage 通过不得变成 whole-device pass |
| 外部求解器 | FreeGS、DESC、Pleiades、FMI、IMAS、OpenPMD adapter | 每个 adapter 独立 manifest、版本锁、适用域、单位/坐标变换、negative control 和 replay |

### C 类：优先复用测试意图和 sentinel

旧 `test/` 的价值主要是测试场景，不是旧断言文本。应优先迁移：

- 解析解、制造解、网格/步长加密和非收敛控制；
- provider missing、ambiguous、out-of-domain 和 manifest mismatch；
- candidate/scenario/mesh/hash 交叉污染；
- 守恒账本、接口通量、边界 ownership 和单位不闭合；
- cache execute-once、shard 顺序不变性、损坏/重复结果拒绝；
- known-device sentinel 与完全新拓扑的对照；
- calibration/validation 混用、同代码伪独立和 manufactured-as-validation 防火墙；
- candidate 失败后保留、dormant/revival 和 scoped no-solution 证书。

迁移测试时必须重新从 v4 公共构造器建立 candidate、plan、provider 和 evidence。不得把
旧 JSON 结果直接包装成新 RuntimeEvidence 来使测试通过。

### D 类：禁止迁移到 v4 核心

以下旧实现只能用于发现反例或理解历史问题：

- 旧 `genome.jl`、旧 candidate/registry/authority/status 类型；
- 按 device family、topology 名称、display name、candidate ID 或固定数组位置选求解器；
- `*_candidate_specific_*`、只对单一装置或单一拓扑有效的偏好性 repair；
- 以默认零源、默认材料、identity interface、猜测边界或 caller-supplied reference 维持链路；
- 把 provider 缺失、不适用、未知或数值不收敛转成物理失败或永久淘汰；
- 中间模块发出 terminal `unsupported`、可信装置或工程 qualification；
- 将同模型不同线性求解器、历史 artifact 或制造解称为独立代码/validation；
- v68–v142 式持续堆叠的单体链文件和隐式全局状态。

## 4. 与当前整链的迁移顺序

当前 D1–D3 已按 v4 合同重建，不应回退替换。D4.1 的 native field residual 正在做限定
验收，应先验收、冻结、提交，再开始以下复用批次。

### R1：D4.1 后立即执行

1. 以旧 `numerical_verification.jl` 和 v87/v94 VVUQ 为测试设计参考，完成 native/Gridap
   双离散的独立数值 V&V；
2. 抽取 `conservation_ledger_compiler.jl` 的守恒核，接入 G1 occurrence ownership；
3. 抽取 `recoverable_sharded_execution_v19.jl` 的内容寻址、原子提交和恢复等价逻辑；
4. 审查 capability router/registry 的匹配维度，映射到 v4 typed signature，不复制字符串类型。

### R2：耦合物理链

1. 迁移 graph residual、multiregion/interface assembly 的算法；
2. 逐项接入 equilibrium、stability、transport、reaction/radiation 和 actuator feedback；
3. 每增加一个物理 block，同时迁移对应的 sentinel、单位、边界、守恒和非收敛测试；
4. 缺 typed producer 的 candidate 保持 deferred，继续其他 candidate/chain。

### R3：工程、VVUQ 与整装

1. 重写材料、磁体、热工水力、结构、功率、控制、保护和故障 provider 外壳；
2. 复用旧 DAG 的 stage 依赖思想，重新由 v4 obligations 编译整装 provider graph；
3. 复用 VVUQ 的网格、参数、场景和独立代码检查逻辑，但重新绑定 subject 和 evidence；
4. admission、execution、closure、final authority 四个权限层保持分离。

### R4：搜索与规模化

只有整链暴露出真实 capability/cost bottleneck 后，才迁移 QD、Pareto、MCTS、multi-emitter
和 campaign。搜索模块只能生成 typed proposal/edit 和预算顺序，不能写 evidence、物理结论
或终局状态。

## 5. 单模块迁移验收门

每个旧模块进入新仓库前都必须留下以下审查记录：

1. **来源**：旧文件、版本、依赖和对应测试；
2. **分类**：纯算法抽取、合同重写、测试迁移或拒绝；
3. **输入映射**：每个输入追溯到 G1/G2/G3、mission、scenario 或显式 protocol；
4. **输出映射**：输出是 artifact、receipt、RuntimeEvidence、gap，还是 proposal；
5. **权限检查**：不得提高旧实现或 provider 的 claim ceiling；
6. **路由检查**：无 family/name/ID/固定位置偏好；
7. **状态检查**：fail、unknown、deferred、unsupported 和 not-applicable 保持分离；
8. **数值检查**：sentinel、negative control、收敛、确定性和 replay；
9. **兼容检查**：不直接 include 旧模块，不暴露旧 Dict schema，不污染新公共类型；
10. **提交检查**：一个能力一个 additive commit，先 focused test，再关键链路回归和 Sol 审计。

只有十项全部通过，旧算法才可作为 v4 provider 或核心模块的一部分。否则它只能留作
reference、oracle 或测试语料。

## 6. 规划调整结论

后续规划应加入强制的 **reuse-first audit gate**：每个新 milestone 开始前，先搜索旧目录中
同能力实现，记录 `extract / wrap / test-only / reject` 决定，再编写新代码。该 gate 只减少
重复开发，不允许降低 typed contract、物理门、独立性或证据门槛。

近期优先级保持为：

```text
冻结 D4.1
  -> 复用审查驱动的 Gridap/数值 V&V
  -> 守恒与多区域耦合残差
  -> 真实物理 provider
  -> 工程/控制/故障与 validation/UQ
  -> 高保真整装及 closure authority
  -> QD/MCTS/campaign 规模化
```

任何复用都不得改变当前事实：制造解和低保真 screen 的可信物理装置数量为 0，不能使
`p5_ready` 变为 true，也不能消除尚无合格 provider 或验证数据的真实 gap。
