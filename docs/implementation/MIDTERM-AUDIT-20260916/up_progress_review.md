# UP0–UP6 中期实质进度审计（2026-09-16）

本审计是对当前 checkout 的只读证据复核，审计对象为 `D:/006-Programing/LMC/FusionConceptAI`。当前 `HEAD=b2c04d8339774635aaecd73651efcdb101e01b5d`，工作树存在大量并发 dirty changes；主审已冻结 5968 文件基线，本文件不重写、不清理该基线。本轮没有修改 source、test、历史 runs 或索引，也没有启动 Julia、DESC 或重数值作业。依据为当前 [`AGENTS.md`](../../../AGENTS.md)、[`README.md`](../../../docs/v4_multitopology_generation/README.md)、[`00_normative_contracts_and_state_model.md`](../../../docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md)、[`16_execution_work_orders.md`](../../../docs/v4_multitopology_generation/16_execution_work_orders.md) 和 [`task_manifest.json`](../../../docs/v4_multitopology_generation/task_manifest.json)。

## 结论口径

| 层级 | 本审计所需证据 | 当前能否由已有材料授予信用 |
|---|---|---|
| 结构合同 | typed schema、版本轴、candidate binding、admission、hash/identity、fail-closed 负控 | 部分可以，主要集中于 UP0–UP1 |
| 软件执行 | 实际入口调用 provider/compiler/mesh/solver，输入由声明驱动且可换组合 | 只有窄的 field screen 和旧 V4 固定空间链 |
| 数值验证 | 收敛、MMS/细化、守恒、独立 checker、失败分类 | W22/W24 是失败或 screen-only；无通过的 V5 物理链 |
| 工程验收 | 源/电源/回流/热/材料/结构/控制的闭环与硬件参数 | 未执行，未授予信用 |
| 物理验收 | 外部域闭合、适用域、独立验证、全场景结果 | 未执行或明确 unsupported |

全父目标仍保留 R01–R10，`L4 credible count=0`。[`UP0-01 acceptance: L102`](../UP0-01/acceptance.md) 的账本明确记录 R01 仅 partial、R02 not implemented、R03 failed current attempt、R06 missing data/providers、R08 partial queue only、R10 not achieved；`runner.exit=0` 不会把 solver exit 4 或 unsupported 升格为通过。

## 分阶段状态

| 阶段 | 当前状态（按证据上限） | 已核实内容 | 未关闭验收项 |
|---|---|---|---|
| UP0 | `accepted_limited`，包含 UP0-01 基线/脏工作树/中断审计与 UP0-02 `pre_result_contract_design` | W22 非收敛；W23 是 G1 0D screen；W24 parent/child 四 case 均 solver exit 4 `iteration_limit`，engineering fail、physical unsupported、whole deferred、credible 0；中断 resume 无 terminal receipt。见 [`UP0-01 acceptance: L88`](../UP0-01/acceptance.md)。UP0-02 只冻结 pre-result contract design，不提供执行信用。 | B00 双进程 canonical package/hash、标签擦除、排列不变和 fresh replay 仍 pending；不能把当前冻结基线写成 B00 通过。 |
| UP1 | 三层合同与 UP1-04A 共享入口为 `accepted_limited`；UP1 整体未接受 | G1 typed mechanism/MIMO/closure、G2 3D 轴对齐几何合同、G3 资源/控制/故障/standalone feedback 合同均有 focused 软件证据；UP1-04A 只证明同候选 shared entry 和结构 join。[`UP1 index: L16`](../UP1-INDEX/acceptance.md) 明确没有 B00/B04/provider/mesh/engineering/physical 信用。 | UP1-04B 的 B00 F0–F5、50 条 fresh B04 receipt、独立 checker、双进程 replay；UP1-04/VNEXT T0/T1/T2；真实跨层 authority、provider resolution、三层迁移；component numerical validation。 |
| UP2 | `planned`/`review_pending`，实际 A slice 只有 contract-only | UP2-00 可从实际 `CandidateStatePackageV5` 投影 typed A 值，N01/N02（及局部 N03/N04/N05/N06/N10 归档）能做 schema/value mutation；校验器强制 50 typed fields、A-limited、`claim_ceiling=none`、`resolution=terminal_deferred`。见 [`TypedPrecompilerContractV1: L1`](../../../src/GenomeV5/UP2/TypedPrecompilerContractV1.jl) 和 [`TypedPrecompilerValidatorV1: L163`](../../../src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl)。 | 50 条正式 B04 receipts、UP1-04B、声明驱动 equation lowering、mesh/materialization、一般入口、外域/回流、耦合 solver、成熟 provider/backend 全部未完成。UP2-01 至 UP2-05 在 manifest 中仍 planned。 |
| UP3 | `planned` | 没有已接受的自动组合执行矩阵或留出组合证据。 | UP2-05 后，必须由 typed ports/equations 自动生成联合系统；held-out 合法组合、标签/顺序擦除、provider dropout、非法配置及守恒账本尚未完成。 |
| UP4 | `planned` | G3 有源、资源、反馈和控制的结构表示；没有 source inverse 或硬件 realization 证据。 | B07A/B07B 是 16 工单中的子协议名称；正式验收仍使用 B03/B06/B07/B08。需完成源/硬件逆设计、热/材料/结构/控制回代、真实参考隐参逆恢复、同一 candidate 的闭环重算和硬件误差证据。 |
| UP5 | `planned` | conditional e-graph 有独立的有界程序派生/trace replay 原语。 | 接入真实 UP4 闭环；条件必须包含单位、域、边界、时序、效应、closure；每条 rewrite 独立 replay，typed edits 必须引起 G1/G2/G3 可观察执行反馈；之后才可做 bounded campaign。 |
| UP6 | `planned` | 当前仍有明确的 capability/evidence ledger 和 R01–R10 边界。 | 全部 required physics/engineering、独立 VVUQ、站级净输出（含储能/供能/辅助损耗）、原创性和独立 fresh replay；最终逐条关闭 R01–R10。 |

## UP1 的“实际使用”边界

typed AST 和 operator hypergraph 不是空类型：[`TypedAST.jl:209`](../../../src/IR/TypedAST.jl) 提供 `TypedASTProgramV1`、canonical/CSE normalization、root/reachability/input 检查；[`OperatorHypergraph.jl:149`](../../../src/IR/OperatorHypergraph.jl) 对 MIMO root、端口 units、effect、interface flux pair 和 conservation ledger 做验证，`AtomicMIMOHyperedgeV1` 还把 typed program 放进 hyperedge。当前 runtime compiler 也确实把 legacy `TypedHyperedge`/`AtomicMIMOHyperedgeV1` 转为 program（[`Compiler.jl:15`](../../../src/RuntimeV4/Compiler.jl)）。因此可以确认“软件结构原语被构造、规范化、校验并在少量路径传递”。

但这不等于 UP2 物理编译。`_runtime_edge_obligation` 只接受单 root；非零维度直接返回 `required_coordinate_declaration`，且 generic G2/G3 graph 被明确视为不足以证明 solver ABI、坐标、边界闭合或 component/control mapping，最后返回 `required_physical_capability:<op>`（[`Compiler.jl:49`](../../../src/RuntimeV4/Compiler.jl)–[`Compiler.jl:80`](../../../src/RuntimeV4/Compiler.jl)）。主 `compile_candidate` 方法签在 `CandidateStatePackageV4`（[`Compiler.jl:102`](../../../src/RuntimeV4/Compiler.jl)–[`Compiler.jl:139`](../../../src/RuntimeV4/Compiler.jl)）；没有证据表明它已成为 CandidateStatePackageV5 的声明驱动方程编译器。

e-graph 同样是“真实但孤立”的软件能力。`derive_conditional_program_egraph` 可在预算内生成程序成员和 provenance，`replay_conditional_rewrite_trace` 会逐步重放并校验 source/target hash（[`ConditionalEGraphSaturation.jl:151`](../../../src/IR/ConditionalEGraphSaturation.jl)–[`ConditionalEGraphSaturation.jl:265`](../../../src/IR/ConditionalEGraphSaturation.jl)）。然而当前 P0 view 对 P1 certificate 明确抛出 unavailable（[`ConditionalEGraph.jl:1`](../../../src/IR/ConditionalEGraph.jl)–[`ConditionalEGraph.jl:12`](../../../src/IR/ConditionalEGraph.jl)），且未发现它被接入 candidate generation、G1/G2/G3 provider 或物理 solver。结论是：typed AST/hypergraph/e-graph 有可执行原语和测试用途，尚未形成生产搜索—物理闭环。

## UP2 实际执行能力与形状限制

当前最接近执行的是 `FieldProgramEvaluation` 的窄 provider。它只选一个 chart；多 chart、chart transition、periodic grid、time-dependent root、nonscalar root 都延期；坐标 map 和 metric 始终记为 `g2_coordinate_map_unexecuted`、`g2_metric_unexecuted`（[`FieldProgramEvaluation.jl:321`](../../../src/RuntimeV4/FieldProgramEvaluation.jl)–[`FieldProgramEvaluation.jl:366`](../../../src/RuntimeV4/FieldProgramEvaluation.jl)）。kernel 只支持 `IDENTITY, ADD, SUB, NEG, SCALAR_MUL, SCALAR_DIV, DOT`，`GRAD, DIV_OP, CURL, LAPLACE, DT` 明确 deferred（[`FieldProgramEvaluation.jl:11`](../../../src/RuntimeV4/FieldProgramEvaluation.jl)–[`FieldProgramEvaluation.jl:14`](../../../src/RuntimeV4/FieldProgramEvaluation.jl)）；执行结果是静态、三维、rectilinear grid 上的标量 screen，claim ceiling 是 `screen_only`。这是真实软件执行，但不是 equation IR→mesh→PDE residual→coupled solve。

G2 V5 admission 的能力更窄且边界清楚：只收 ambient 3、Cartesian、linear mesh，检查 region/interface/exterior patch ownership、面片覆盖、`trace_flux`、`conservative` transfer、六面外边界闭合和 boundary condition（[`FieldGeometryGenomeV5.jl:134`](../../../src/GenomeV5/G2/FieldGeometryGenomeV5.jl)–[`FieldGeometryGenomeV5.jl:207`](../../../src/GenomeV5/G2/FieldGeometryGenomeV5.jl)）。这些是结构/几何条件；`g2_admission` 无论结构是否有效，都返回 `mesh_status=:not_executed`、`physical_status=:not_executed`（[`FieldGeometryGenomeV5.jl:217`](../../../src/GenomeV5/G2/FieldGeometryGenomeV5.jl)–[`FieldGeometryGenomeV5.jl:230`](../../../src/GenomeV5/G2/FieldGeometryGenomeV5.jl)）。没有看到从 V5 `FieldSpacePlanV2` 实际物化 mesh、quadrature、metric 或 face flux 的通用入口。

旧 `SpatialMultiRegionV4` 是另一条可运行的固定模型路径：固定 Q1、两 radial regions、固定 4 dofs/node 和旧 declaration guard；它可计算 interface/outer diagnostics，但结果明确写 `external_current_closure=:unsupported`、`conservation_certified=false`、`physical_validation=:unsupported`（[`SpatialMultiRegionV4.jl:333`](../../../src/RuntimeV4/SpatialMultiRegionV4.jl)–[`SpatialMultiRegionV4.jl:342`](../../../src/RuntimeV4/SpatialMultiRegionV4.jl)）。`SpatialCandidateV4` 还硬编码旧 spatial declaration、固定 G1/G2/G3 和 pickup/RL realization chain（[`SpatialCandidateV4.jl:130`](../../../src/RuntimeV4/SpatialCandidateV4.jl)–[`SpatialCandidateV4.jl:199`](../../../src/RuntimeV4/SpatialCandidateV4.jl)）。因此旧链可作为 numerical screen/回归 fixture，不能计为 UP2 V5 的 general compiler 或 G2 conservation proof。

## G2 网格守恒、外部域与 G3 逆反馈的实情

G2 当前能证明的是“声明的拓扑/面片关系自洽”：接口共面、切向覆盖、方向、trace/flux continuity、conservative transfer 与外侧 patch coverage 有 fail-closed 检查。它不能证明积分通量真的经过网格装配，也没有外域网格、远场截断敏感性、源/回流闭合或重网格前后守恒数值。UP2-03 的明确退出门要求转移前后总量差在冻结容差内、外域细化敏感性通过，并以删外域/漏回流为负控（[`16_execution_work_orders.md:599`](../../../docs/v4_multitopology_generation/16_execution_work_orders.md)–[`16_execution_work_orders.md:617`](../../../docs/v4_multitopology_generation/16_execution_work_orders.md)）；现有证据未达到该门。

G3 当前能证明的是资源/账户/控制/故障/feedback 的结构和同候选 ref 约束。反馈 validator 明确指出 supplied values 相等不建立 provenance，仍加入 `feedback_authority_gap`；`g3_compare_feedback_target_refs` 只是按值比较，永远不清除 authority gap（[`CoupledRealizationControlBindingV2.jl:86`](../../../src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl)–[`CoupledRealizationControlBindingV2.jl:94`](../../../src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl)、[`CoupledRealizationControlBindingV2.jl:185`](../../../src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl)–[`CoupledRealizationControlBindingV2.jl:191`](../../../src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl)）。G3 realization child edit 的 `physical_resolution` 被限制在 `unknown`/`terminal_deferred`，本地 receipt 不能提升为物理结果（[`G3RealizationChildEditabilityV1.jl:577`](../../../src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl)–[`G3RealizationChildEditabilityV1.jl:586`](../../../src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl)）。所以当前没有“源逆设计→主场求解→热/结构/控制回传”的真实闭环；旧 pickup/RL 只是固定 realization fixture。

## 阻塞判断

真正的能力/证据阻塞包括：

1. G2 coordinate map/metric、通用 mesh/face ownership/assembly 尚未有 provider；变系数、各向异性、导数、时间项和多场 lowering 尚未实现。
2. 外部区域、远场截断、外部电流/outer sheet、源回流和 G1 conservation ledger 没有可执行闭合；已有 W24 数值还在 exit 4 `iteration_limit`。
3. G3 没有同候选 source authority provider，也没有电路损耗、热、材料、结构、控制反馈回算；真实 reference/inverse 数据缺失。
4. UP3 的 unseen composition、UP4 inverse realization、UP5 search feedback、UP6 whole-device physics/VVUQ/net output 均无接受证据。

架构流程制造或主动维持的“阻塞”则应单独记账：UP2-00 的 invocation counter 故意禁止 provider（[`PrecompilerInvocationCounterV1.jl:20`](../../../src/GenomeV5/UP2/PrecompilerInvocationCounterV1.jl)–[`PrecompilerInvocationCounterV1.jl:22`](../../../src/GenomeV5/UP2/PrecompilerInvocationCounterV1.jl)）；V5 migration、candidate identity、authority receipt、B00/B04 双进程和 `terminal_deferred` 是防止伪造证据的门；G2 的轴对齐 3D 限制、field screen-only 限制、e-graph budget 也是声明范围。这些门本身合理，但“门尚未完成”不能被写成“物理求解器已失败”，也不能以局部 focused test 或 runner exit 代替。当前存在的流程债务是：UP1-04B/B00/B04 formal replay 未做、VNEXT T0/T1/T2 仍 planned，以及 upstream declaration 改动后需要重建 candidate identity/receipt；它们解释为何后续 UP2 被串行锁住，但不能掩盖上述 provider/solver/外域的真实缺口。

## 可执行的下一步

1. **先关 formal identity gate。** 在新鲜 candidate-bound 输入上完成 `UP1-04A-VNEXT → UP1-04B`：冻结 G1/G2/G3 public refs、四轴、source/declaration hashes；实现 B00 F0–F5、50 条 B04 receipt、独立 checker 和两个独立进程的 tag-erasure/permutation replay。任何 upstream 改动后重建全部 identity，不复用旧 receipt。
2. **实现 UP2-01-G2 的最小真实 slice。** 建议把声明驱动 chart→metric、region mesh、exterior/interface face ownership 和 quadrature/flux materializer 放在 `src/RuntimeV4/` 或新的专属 spatial/equation 模块，并由集成入口接入；这只是建议写入范围，不是唯一架构路径。以 G2 plan 改变 cells、interface 或 boundary 的 candidate-bound fixture 验证输出改变，并保留 multi-chart/periodic/非 Cartesian 的明确 deferred。不得借改 `default_operator_registry()` 取得能力。
3. **实现 UP2-01-G1 manufactured diffusion。** 建议在现有 compiler/field evaluation 邻近模块或新的专属 lowering 模块落地，让 typed AST/operator binding 真正 lower 成变系数/各向异性 `GRAD/DIV` residual；这是建议路径，不是唯一架构路径。保留 field screen 作为 fixture；用变量系数、单位错误、边界缺失、导数缺口和 MMS mesh refinement 验证 residual、收敛阶及 AD/解析/数值 derivative metadata。
4. **实现 UP2-01-G3 source/feedback authority。** 建议沿现有 G3 binding/child edit 模块增添 source、return、heat-sink、ledger 和 feedback target 的 candidate-owned provider receipt；该文件归属是建议，不是唯一架构路径。缺外部 authority 仍 `terminal_deferred`，冲突 `fail_closed`。只有 provider 执行、账本守恒和回传到 G1/G2 后才可转入 UP2-02/03。
5. **完成 UP2-02/03 外域与守恒反例。** 用同一入口执行区域连接、重网格/投影、接口 flux 和外域/远场；做转移前后总量差、divB/正性、局部误差、外域细化敏感性，删外域和漏回流必须失败。把 W24 exit 4 保留为 numerical failure，不能调阈值抹掉。
6. **随后做 UP2-04/05 和 UP3。** 以强耦合块/DAE、规范零空间、初值一致性、故意错误 Jacobian 为负控，登记每个 provider 的适用域；再由 typed ports 自动组合，做未见合法组合、标签/排序擦除和 provider dropout，禁止 candidate-specific 方程分支。
7. **最后释放 UP4–UP6。** 先完成受约束 source/hardware inverse，再做热/材料/结构/控制反馈和真实参考隐参留出反演；之后接 e-graph rewrite replay、typed G1/G2/G3 edits 和 bounded search。UP6 必须补齐 required physics、独立 VVUQ、全周期净输出和 R01–R10 逐项 authority，直到一个候选同时通过适用最终门前，`L4` 保持 0。

## 结论分类

**已核实：** UP0–UP1 的有限合同范围、typed AST/hypergraph/e-graph 的软件原语、field provider 的 screen-only 执行、V5 G2 admission 的结构检查、G3 feedback authority gap、旧 V4 spatial 数值链的固定模型和 unsupported/iteration-limit 状态均可由当前源码及已归档 receipts 定位。

**推断：** 由于当前 `compile_candidate` 的 V4 类型签名、V5 G2 admission 的 `not_executed` 返回值以及 absence of V5 mesh/provider caller，本审计判断 UP2 尚未形成通用 V5 declaration-driven physics compiler；这是从代码路径和 manifest 推断的架构状态，不把“未发现 caller”冒充运行时全局证明。

**未执行：** 本轮没有启动 Julia/DESC、没有重跑 W24、没有运行 focused tests，也没有声称 solver 收敛、mesh conservation、external-domain closure、source inverse、hardware/engineering、physical validation 或 R01–R10/L4 改善。无需代码测试的理由是：任务是冻结基线上的只读实质审计，已有 acceptance/runs 与源码已经足以判定当前证据上限；新增运行会改变/竞争冻结队列和 artifacts，且不会把 contract-only 代码自动变成物理证据。
