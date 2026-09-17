# 现状审计：哪里完成，哪里没有完成

## 1. 结论与核验范围

审计基线为 2026-09-13 的 `c9ee990`。只读核查当前源代码、包含关系、测试入口、最新运行 JSON/日志以及旧版反解报告；本轮重跑历史产物的独立哈希/阶段检查，结果为 **549 条记录、548 个唯一路径、0 不匹配，进程 exit 0**，见 [复核结果](current_artifact_audit.json)。没有重新运行昂贵的 Julia/DESC 四工况求解或整个回归套件。

最新链已经真实调用 DESC、组装空间系统并更新未知量，工程也真实读取这些状态的电流。**执行链到终态了；科学成功链没通，发现循环更没通。** 物理解算全部失败，独立物理验证缺失，整装输出固定 deferred，可信数为 0。

不报告“总完成 70%”之类数字，因为没有完整且加权冻结的需求分母。下面采用可检查的完成度：0=当前路径未实现，1=合同/接口，2=局部可执行，3=该范围集成并有实际运行，4=通过最终目标对应的验收。此等级不是等距分数，也不代表最终项目完成比例。

## 2. 模块完成度

| 模块 | 当前完成度 | 已有实际能力 | 距离总目标的缺口 |
|---|---|---|---|
| G1 机制 Genome、G2 场与几何、G3 实现与控制 | 3（已实现部分） | 不可变结构、类型/单位、哈希与所有权检查；当前候选能形成 G1/G2/G3 绑定 | 不等于任意完整装置都可编码；开放 payload、完整硬件/物理声明仍需闭合 |
| typed AST、operator hypergraph、canonical/e-graph | 3（有界功能） | 类型检查、规范化、有限等价性和证据隔离 | 不是物理可信、全局原创性或全部搜索空间可达证明 |
| 编译、capability 路由、provider 收据、恢复与审计 | 3（有限链） | 候选/输入/场景/环境/结果绑定，真实进程和检查点恢复 | 支持的 solver 能力有限；缺 producer 的义务仍不能被执行 |
| 几何解释与几何兼容证明、FreeGS/DESC 接入 | 3（特定适用域） | narrow Fourier 几何与 DESC 实际 HDF5/场/界面采样；FreeGS 独立历史 fixture | 几何证明不等于物理平衡验证；一个后端不能代表任意机制与拓扑 |
| 原生/独立场核、时间/DAE/多区域基础 | 2–3（子功能） | manufactured control、有限场残差、时间执行及数值比较 | 尚非候选完整动态输运、燃烧、稳定性或整机耦合 |
| 最新空间多区域静态求解 | 3（执行）／科学验收未通过 | 360/2640 自由度、2881/21761 行、完整稀疏 Jacobian、四工况真实迭代 | 四案 exit 4；nominal_coarse 已确认近压力边界数值停滞；压力/电流拓扑与外部边界闭合仍缺 |
| 工程、控制、故障 | 3（拾取子系统）／整装工程未验收 | 实际 J/K 到有限孔径拾取线圈；静态磁通、条件性 RL/10 μs 保护计算 | 仅局部电磁诊断；外部线圈/返回电流、热、结构、材料、燃料循环、发电负荷未闭合 |
| 数值 verification | 3（本次检查范围） | 独立残差检查、所有 Jacobian 列、两级非零源 MMS 检查、独立电路恒等式 | MMS 没有执行解的收敛阶验证；失败粗细解不能证明解收敛 |
| 物理 validation 与 UQ | 1–2（协议与有限传播） | 有声明/证据要求，实际做 ±5% 磁通端点传播 | 物理 validation 未执行；无可用观测、独立物理数据/模型差异依据；端点不是置信区间 |
| 输运、燃烧、稳定性、整机能量账本 | 0–1（当前可信整链） | 设计义务与历史参考实现可查 | 当前空间链没有从候选自洽状态导出完整聚变功率及站级净输出的路径 |
| 已知装置真正反解与盲留出验证 | 0（当前 v4 完整路径） | 旧版已有描述编码、有限电流势反求与 reference 回放 | 当前没有 ITER→同一 solver→多初值反演→留出预测的统一基准管线 |
| 开放式搜索、QD/MCTS、原创性 | 1–2（基础设施） | 有候选队列、休眠/恢复、提议信道和规范化 | 没有接入整机评价的真正 G1/G2/G3 生成—求解—档案反馈循环；没有最终原创性证据 |
| Whole-device authority 与可信输出 | 依赖账本 3／最终 authority 1 | 可检查当前阶段依赖与缺口，诚实输出 deferred | 证据类型和构造器拒绝更高等级，缺乏真实 producer 支撑的可晋升路径；L4 结果 0 |

基础包入口见 [FusionConceptAI.jl](../../../src/FusionConceptAI.jl)、[RuntimeV4 聚合器](../../../src/RuntimeV4/FusionRuntimeV4.jl)、[runtests.jl](../../../test/runtests.jl)。具体历史子模块验收见 [current_progress_index.md](../current_progress_index.md)，其历史测试数不能直接相加为当前整机覆盖率。

## 3. 最新一条链到底运行了什么

当前空间候选 `3de9cf49553e4f2ceaa0aa93330388f8b5c740f1706df9352a71229fe459502e`，上下文 `0f7521a157ca710b195f82757a8d204058d99231b12346f9c8f37d9be526b10d`。

```text
固定示例的子候选 + G1/G2/G3
  → 新鲜 DESC 请求/HDF5/场与几何采样                 已执行
  → 两区域、同材料、固定几何、静态无流空间求解      已执行，四案失败
  → 实际电流 J/K 到拾取线圈和条件性电路             已执行，上游无效
  → 数值公式/Jacobian/MMS/电路检查                  检查通过，非物理验证
  → 独立物理验证                                   缺数据与能力，未执行
  → 全装置燃烧/热工/供能/净输出/稳态和故障资格      未形成完整计算
  → 可信性 authority                               deferred，0 个可信装置

G1/G2/G3 原创生成 → 上述通用评价 → 搜索档案反馈     当前没有闭环
ITER 等盲反解 → 同一正向评价 → 留出基准            当前没有闭环
```

| 工况 | 自由度 / 残差行 | 接受更新数 | 最终 scaled L2 norm | 物理退出 |
|---|---:|---:|---:|---|
| nominal_coarse | 360 / 2881 | 12 | 0.1614574 | 4 / iteration_limit |
| nominal_fine | 2640 / 21761 | 4 | 0.1379660 | 4 / iteration_limit |
| flux_low_coarse | 360 / 2881 | 12 | 0.1563471 | 4 / iteration_limit |
| flux_high_coarse | 360 / 2881 | 12 | 0.1653056 | 4 / iteration_limit |

注意源码成功门判断的是 `maximum(abs, scaled residual) <= 1e-6`，不是上述 L2 norm。粗网格最终 max 为约 0.01293896，是门槛的 12939 倍；不是“几乎通过”。见 [SpatialMultiRegionV4.jl:172](../../../src/RuntimeV4/SpatialMultiRegionV4.jl#L172)。

工程静态磁通约 −1.30e−5 至 −1.87e−5 Wb，静态感应电动势为 0。这是拾取线圈读数，不能作为发电结果。条件性规定 ramp 的 RL 响应也不是自洽等离子体动态求解。

最初整装调用发生 Julia world-age 程序异常，保留 exit 1；修复后 resume 重用已有检查点，整合断言 43/43、外层 exit 0。**外层成功表示失败结果被正确处理，不代表物理求解成功。** 见 [当前空间运行报告](../spatial_coupled_execution_v4_20260913.md)及 [原始 evidence JSON](../spatial_coupled_execution_v4_20260913_evidence.json)。

## 4. 当前最具体的数值阻塞：近零正压力卡住步长

对现有 nominal_coarse 状态与求解尝试记录的复核发现：

- 迭代 8 到 12 的 scaled norm 恒为 `0.16145739547560198`，projected gradient 恒为 `0.025367706113226543`。
- 后四次所谓接受更新中，360 个状态只有首节点压力变化：约 `7.1054e-15 → 7.8886e-31 → 8.7581e-47 → 9.7235e-63 → 1.0795e-78 Pa`；磁场与其余压力没有变化。
- 最后 alpha 约 `6.7471e-69`。由记录的压力、列尺度和方向代入 `-p/(p_scale*step_p)` 可复算该值。
- active-set 仅在 `p<=0` 时将对应受约束自由度激活；正的极小 p 一直没有被激活。可行步长因此被它限制；fallback 仅判断 `alpha==0`，不会处理极小正值。
- `trial != x` 仅要求存在任何浮点变化；Armijo 非严格比较在舍入后允许目标函数完全不降而接受更新。

证据位置：[SpatialMultiRegionV4.jl:166](../../../src/RuntimeV4/SpatialMultiRegionV4.jl#L166)、[199–224 对应起点](../../../src/RuntimeV4/SpatialMultiRegionV4.jl#L199)、[接受更新处](../../../src/RuntimeV4/SpatialMultiRegionV4.jl#L232)。

因此“加大迭代次数”不是首选。先用当前失败工况重现，检查尺度一致的 active-set/KKT、可行步长和停滞判据；将舍入无进展与真实下降分开。修复不得通过抬高物理容差、删残差、固定多数未知量、偷加压力锚点或跳过细网格来获得 pass。

这是已定位的算法停滞机制；**尚未证明它是全部不收敛原因，更未证明修复后该模型存在符合边界条件的解**。还需独立检查方程闭合、约束兼容性、测试空间与边界重复/冲突、零空间和尺度。

## 5. 确实存在能力与验收范围收缩

不能从代码推断以前代理的主观动机，但以下客观现象成立：

| 原目标 | 当前被验收的替代范围 | 具体证据 |
|---|---|---|
| 完整空间物理解算 | 早期四幅值、36 行降阶模型；之后才补真正空间自由度 | 最新报告明确把 `51b5540` 标为历史 reduced milestone，不能沿用为空间成功 |
| 成功物理链 | “同一候选执行过求解尝试” | `SpatialWholeDeviceV4.jl:53` minimum 主要检查 executed；不要求科学成功 |
| 完整装置工程 | 拾取线圈、理想电路和条件性故障响应 | `spatial_execution_contract_v4.md` 的工程声明和 Remaining edges |
| 高等级可信证据 | screen_only 收据、独立公式/数值比较、deferred 输出 | `Contracts.jl`、`WholeDevice.jl`、`SpatialWholeDeviceV4.jl` 固定的权限上限 |
| 已知装置反解成功 | 描述编码/有限降阶回放及独立 reference 汇总 | 旧版 v102 检出 reference pass 与普通候选 physics fail 的分歧 |
| 开放式原创发现 | 固定示例后代、队列及执行链脚手架 | `SpatialCandidateV4.jl:130` 起与 `Search.jl` 实际实现 |

现有文档明确承认这些边界，所以不能概括为“所有实现都是假的”。但如果把这些局部里程碑不断用作原始 Goal 的完成标准，确实会形成“局部完成很多、最终目标始终没有可达路径”的问题。

尤其是 [WholeDevice.jl:25](../../../src/RuntimeV4/WholeDevice.jl#L25) 直接拒绝 `p5_ready=true`、`goal_acceptance=true`、终局分类；[SpatialWholeDeviceV4.jl:33](../../../src/RuntimeV4/SpatialWholeDeviceV4.jl#L33) 只容许 deferred/unsupported/0，结果构造再次固定这些值。单纯让当前 solver 收敛，也不可能由这个入口输出可信结果。

应保留 screen 构造器的限制，按 [sol_runtime_plan.md:27](../../implementation/sol_runtime_plan.md#L27) 原本要求，**增加独立、严格验证真实来源和独立性的高等级 evidence 与 authority 通路**。直接删除 false/0 防火墙只会产生虚假的成功。

## 6. 旧版 ITER/C-2W 的教训

[旧版 v102 报告](../../../../outputs/fusion_concept_ai/reports/v102_inverse_reference_candidate_experiment_20260829.md) 已记录：reference 汇总 2/2 pass，但同两状态进入普通候选 v98 后 0/2；检出 2 个 reference-control bypass。ITER 被错误施加其研究任务未声明的净电要求；C-2W 也遭受不适用的 D-T/净电/中子壁负荷筛选。该拒绝不能上升为这些装置的物理失败。

旧版 `inverse_compile_reference_realization_v89` 直接读取 anchor 的 parameters/initial_conditions，再填装置组件模板。这可作为表示导入和回放，不是隐藏参数数值反演。旧版 v86 确有有限曲面电流势的优化反求，但也不是整个 ITER 的反演。不能把历史“inverse”标签继承为 v4 已有完整反解能力。

正确目标应是：相同代码、相同单位和证据规则、由物理任务导出的适用门；让已知装置通过它应通过的基准，同时让 ITER 保持“非发电实验装置”，不伪装成净电正例。

## 7. 为什么绿测多却没有可信结果

1. 很多测试验证哈希、身份、拒绝错误来源、失败归档和 manufactured 数值恒等式；它们可以全绿，同时物理问题没有一个合格解。
2. `test/runtests.jl` 没有包含 `runtime_v4_*`。记录的 2631/2631、105 组是包范围回归；空间链另有 focused 和 runner 整合测试。它不能称为所有 RuntimeV4 的总回归。
3. 标准包不直接导入 RuntimeV4；最新链通过 example/runner 的动态 include 装配。可以执行，但集成/版本一致性需要独立入口保障；这也与发生过的 world-age 故障有关。
4. 脏工作树包含旧的未跟踪合同、样例与测试，以及已修改的 `test/runtime_v4_validation_uq_execution_request_tests.jl`。文件存在不等于已经集成验收；不可全目录暂存来掩盖这个差别。
5. 当前没有验证过的输运/燃烧/工程/净能量 producer，没有盲反解基准，也没有开放式发现循环。可信数为 0 不只是“authority 太严格”。

优先恢复顺序为：**原始目标与集成验收账本 → 当前数值停滞和方程闭合 → 已知装置适用基准与真反解 → 全装置物理/工程/能量和验证 → 高等级证据晋升 → 开放式发现与原创性独立审查。** 简单搜索器可并行开发和早期接入基准，但在评价器未校准时不得扩大搜索或宣称发现。
