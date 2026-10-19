# 代码入口、兼容层与历史源码

本页规定当前目录职责。运行结果与未完成门统一见
[root 当前关键路径](implementation/GOAL-EXECUTION-20260926/critical_path_current.md)。
同名或带版本号不表示实现等价；归并依据是实际调用、合同、源身份和测试覆盖。

2026-10-19实验Goal已暂停。最新入口、单位和验证范围见[实现记录](implementation/IMPLEMENTED-STATE-20261019/implementation.md)。本次按用户授权汇总并删除大部分历史raw与无用版本，逐文件SHA及可复放限制见[清理记录](implementation/WORKSPACE-CONSOLIDATION-20261019/README.md)。

## 目录职责

| 目录 | 职责 |
|---|---|
| `src/` | 当前生产合同、编译器、物理算子与求解器实现 |
| `tools/` | 可复用工具及薄业务适配器 |
| `scripts/` | 用户、CI 与受监督运行的入口；转发实现，不复制算法 |
| `test/` | 当前回归、负例和独立数值 oracle |
| `test/fixtures/` | 测试样本与只读历史输入索引 |
| `examples/` | 演示候选构造和使用方式 |
| `benchmarks/` | 参考源输入及来源信息 |
| `runs/`、`tmp/` | 本地收据、pins与明确保留的暂停输入；大部分旧raw已汇总删除，默认不纳入新提交 |

受保护的 `examples/runtime_v4_declared_fixture.jl` 暂留原路径；现用调用图仍依赖它。
归档中的源码是历史数据，不承诺能在新路径直接执行。原命令、退出码和哈希保留原含义。

## 已有的公共兼容层

| 边界 | 现用核心与消费者 | 继续开发的约束 |
|---|---|---|
| 候选、能力、provider、求解输入与 evidence 绑定 | `src/RuntimeV4/Contracts.jl`、`Capability.jl`、`Execution.jl`；FieldResidual、Algebraic、Typed DAE、Q1 与 Native Gridap 已消费 | 共用现有绑定；各求解器保留数值协议、backend 身份、专用报告、缓存验证与失败分类 |
| 带界线性步 | `src/RuntimeV4/Solvers/BoundedLinearStep.jl` 委托现有 `SpatialBoundedLinearStepV1` | 单一算法实现；独立 KKT 审计与测试 oracle 保持独立 |
| 非线性 accepted step | `src/RuntimeV4/MultiTopologyNonlinearSolveV1.jl`；GlobalWeak 与 Coupled 当前源码调用 | 共用事务、输入与 source 验证；各自保留真实组装、SparseQR/KKT、feasibility/Armijo、预算和失败分类。机制预检不替代真实消费者 |
| 历史源码读取 | `tools/workspace_sources.py::HistoricalSourceReader` | 明确 index、ZIP、snapshot 与每个成员的字节/SHA；不提取、不执行、不自动改用本地文件 |
| T2 的当前源与历史数据分类 | `tools/execution/t2_source_inputs.py::T2SourceInputs` | 薄业务绑定只属于 T2；其他模块直接复用通用 reader，并保持各自冻结输入合同 |

GlobalWeak 与 Coupled 的组装、守恒、trace 和 fresh replay 合同保留各自所有者。
它们未接通的通用输入或完整求解不能用新的结果外壳补成已实现。

## 当前入口及并行所有权

旧T2专项已取消。兼容入口 `scripts/vnext_t2.py build|verify|run`逐字转发原参数，继承标准输入、标准输出和标准错误，并保留退出码。
其三个现用 R23 实现暂留冻结兼容路径，避免更改 `__file__` 与旧协议身份。
后续修复原位更新这些实现，重新冻结当前输入；不复制整套代码生成 R24。
有界检查使用 `scripts/run_bounded_check.py`，保留原命令和独立进程收据。
Coupled 软件控制使用 `scripts/run_coupled_numerical_controls.py --output-dir NEW_RUN_LEAF`，继承现有监督器并在不同新进程执行完整 producer 与 exact-byte fresh replay；历史 runs launcher 仅保留原证据。现用源加载错误已原位修复，原producer/fresh各141/141实际通过；仅属numerical_mechanism_only，当前按生命周期优先调度暂停新运行。

公共合同和共享入口每次仅一个所有者；实施、测试和独立复核由不同角色承担。
Julia、DESC、FreeGS、网格及完整回归由 root 排入同一串行计算通道。
版本号只用于确有不同冻结 schema 或数学合同的兼容边界；小修复在现用文件中完成。

## 迁移与退休条件

先核对所有当前调用与输入 pin，保存精确 preimage 和逐路径清单，再改变入口。
同名文件的独立 oracle、唯一负例和不同数学合同不能因名字相似而移除。
只读归档提供原始输入身份，不提供数值、物理或正式验收信用。
迁移后若出现新失败，先恢复受影响文件，修复漏网引用，再复测原消费者。
旧失败结论、独立复核方法及当前输入的保留范围以2026-10-19清理清单为准。摘要不恢复已删除的原始字节；后续复放缺输入时必须重新生成并写新收据。历史归档reader只能读取实际存在且哈希匹配的归档。

已退休UP1外部认证r2–r4及UP4历史协议wrapper家族见[退休记录](implementation/WORKSPACE-CONSOLIDATION-20261019/retired_code.md)。生产FreeGS两条runner和独立参考测试保留。PhysicalEdgeObligation、SearchPhysicalConsumer、CandidateStatePackage、G3MaterialFieldProjection及UP2ClosureReplayOnly中的旧合同仍有实际导入、冻结身份或独立oracle，不因版本号删除。

Native 的 `focused_tests_r14_compile_min.jl` 是当前 R30 的运行对象；
同字节的 `focused_tests_r12_markers.jl` 是前代命令差分的输入。
214 项冻结 pin 分别绑定两条路径，当前两者仍留原位。
迁移前代输入时必须重建其读取与协议闭包；不能删一条 pin 或将前代输入当成当前测试通过。
