# 当前剩余工作单与接口责任（2026-10-19）

实验 Goal 已由用户暂停。本轮仅整理实现、清理授权范围并提交代码；以下计算任务等待用户恢复。机器状态见 [task_manifest](task_manifest.json)，已实现内容见 [实现记录](../implementation/IMPLEMENTED-STATE-20261019/implementation.md)。

## 执行与验收边界

- root 独占共享入口、正式运行和最终裁决；实施、测试、独立复核分离，最多九个 GPT-6 Luna/high 子智能体。
- Julia/DESC/FreeGS/网格重计算串行，4 GiB；保留各门原预算、科学阈值、适用范围与完整资源覆盖。
- 真实输入 → 同候选状态/区域/面/法向/积分/DOF 映射 → 适用物理律 → 全局 R/J → 原消费者。局部 helper 或文档不替代完整接线。
- 复用仍适用的合格结果。每次新长跑须有具体失败原因、对应修改与受影响短检查；旧 T2、Q1_8残差降低不恢复为前置。
- 原始大产物按用户本次清理指令汇总后删除；[运行摘要](../implementation/IMPLEMENTED-STATE-20261019/run_history.md)明确保留、删除及需重新生成的范围，摘要不替代原始复放证据。

## 当前接口与缺口

### pressure_topology — HOLD
- 输入：`src/RuntimeV4/CandidateCoupledPhysicsV4.jl`；`src/RuntimeV4/InHouseCoupledMHDGlobalSolveV1.jl`；`test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl`；`runs/e/up2_ideal_periodic_actual_producer_20261009_r1/provider_artifacts`；`tmp/native_hagenow_owned_work_20261006/g2_outer_face_map_gap_20261008/actual_g2_callback_precheck.jl`。
- 消费者：test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl::_test_actual_native_current_conservation -> CandidateCoupledPhysicsV4 full-native callbacks -> InHouseCoupledMHDGlobalSolveV1::assemble_coupled_mhd_global_v1
- 剩余门：压力关系及稀疏导数有限范围已有证据；尚缺同一终态进入完整 global R/J、可接受 KKT 步及原消费者 A/B。
- 下一条件：实际压力法/界面关系进入全局R/J；变化状态独立oracle通过，再原完整消费者A/B。

### current_topology — HOLD
- 输入：`src/RuntimeV4/CandidateCoupledPhysicsV4.jl`；`src/RuntimeV4/InHouseCoupledMHDGlobalSolveV1.jl`；`test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl`；`runs/e/up2_ideal_periodic_actual_producer_20261009_r1/provider_artifacts`。
- 消费者：test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl::_test_actual_native_current_conservation -> CandidateCoupledPhysicsV4 full-native callbacks -> InHouseCoupledMHDGlobalSolveV1::assemble_coupled_mhd_global_v1
- 剩余门：64点离散 Jn 与局部根/导数诊断不能证明全 LCFS 连续约束；完整点值误差界、gross/signed 积分和终态守恒仍缺。
- 下一条件：同场表示兼容与LCFS cut map短检；适用保守关系进真实global消费者，保留GS4并验证误差预算。

### B_out — HOLD
- 输入：`src/RuntimeV4/CandidateCoupledPhysicsV4.jl`；`src/RuntimeV4/InHouseCoupledMHDGlobalSolveV1.jl`；`test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl`；`runs/e/up2_ideal_periodic_actual_producer_20261009_r1/provider_artifacts`；`tmp/native_hagenow_owned_work_20261006/g2_outer_face_map_gap_20261008/actual_g2_callback_precheck.jl`。
- 消费者：test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl::_test_actual_native_current_conservation -> CandidateCoupledPhysicsV4 full-native callbacks -> InHouseCoupledMHDGlobalSolveV1::assemble_coupled_mhd_global_v1
- 剩余门：完整64点 near/far B/J 尚未交付；最新直接边界桥未产生合格 native B/J，FAR成本预测仅为估计。
- 下一条件：真实LCFS双侧field/DOF及修改列FD；统一opt-in原消费者和全局A/B。

### K_outer — HOLD
- 输入：`src/RuntimeV4/CandidateCoupledPhysicsV4.jl`；`src/RuntimeV4/InHouseCoupledMHDGlobalSolveV1.jl`；`test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl`；`runs/e/up2_ideal_periodic_actual_producer_20261009_r1/provider_artifacts`。
- 消费者：test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl::_test_actual_native_current_conservation -> CandidateCoupledPhysicsV4 full-native callbacks -> InHouseCoupledMHDGlobalSolveV1::assemble_coupled_mhd_global_v1
- 剩余门：LCFS双侧场/面电流及其完整64点同状态导数尚未在全局消费者闭合；计算盒边界不能替代 LCFS。
- 下一条件：与B_out共用实际trace，验证K关系及J；无重复约束，原global消费者A/B。

### return_current_path — HOLD
- 输入：`src/RuntimeV4/CandidateCoupledPhysicsV4.jl`；`src/RuntimeV4/InHouseCoupledMHDGlobalSolveV1.jl`；`test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl`；`src/RuntimeV4/FreeGSAxisymmetricExecution.jl`；`runs/e/up2_ideal_periodic_actual_producer_20261009_r1/provider_artifacts`。
- 消费者：test/runtime_v4_freegs_axisymmetric_lcfs_trace_tests.jl::_test_actual_native_current_conservation -> CandidateCoupledPhysicsV4 full-native callbacks -> InHouseCoupledMHDGlobalSolveV1::assemble_coupled_mhd_global_v1
- 剩余门：理想周期声明已明确，但完整周期切面 signed/gross 电流包络、实际路径守恒及同状态消费者仍缺。
- 下一条件：在候选真实输入显式声明周期等离子体与LCFS J·n=0，推导/验证J与法向/切面及守恒J列；接global R/J，非零法向/断边负控与原消费者A/B。若新声明改变候选身份按正常流程生成新候选，不改旧payload/失败，不新建协议框架。

### solver — HOLD
- 输入：`src/RuntimeV4/InHouseCoupledMHDGlobalSolveV1.jl`；`test/RuntimeV4/InHouseG1G2Q1SolverV1`；`src/RuntimeV4/CandidateCoupledPhysicsV4.jl`。
- 消费者：InHouseCoupledMHDGlobalSolveV1::assemble_coupled_mhd_global_v1
- 剩余门：C771 r17 在4 GiB内完成资源门但未通过原 KKT/Schur/pressure 门，没有接受步；Q1_8按用户决定保留当前有限状态，2080列FD及完整fresh replay未完成。
- 下一条件：只验证影响UP2的装配/J/约束短检；完整FD/复放和新拓扑列入单独能力门，不恢复已取消的Q1_8降残差工作。

### up3 — HOLD
- 输入：`src/RuntimeV4/DeclaredSpatialCompositionExecutionV1.jl`；`src/RuntimeV4/DeclaredG123DiffusionExecutionV1.jl`；`test/RuntimeV4/DeclaredDiffusionCompileExecute/thermal_slab_actual_source_focused_test.jl`；`src/GenomeV5/Integration/VNextCurrentSourceT0T1EntryV1.jl`；`src/GenomeV5/Integration/VNextUP3ThermalQueueChildV1.jl`。
- 消费者：VNextCurrentSourceT0T1EntryV1::_vnext_current_source_records_v1 -> VNextUP3ThermalQueueChildV1 -> existing thermal_slab_actual_source_focused_test.jl -> DeclaredSpatialCompositionExecutionV1 coupled consumer
- 剩余门：DCCE focused r21 全部通过；Q1 dispatch r4 20次求解仅screen；full17 r2 OOM、r3测试对象生命周期失败、r4资源审计缺口，整体未接受。
- 下一条件：先修现有Profile导出并短测source_records/T1；复用合格R14证据，行为变更回归通过后完整文件/17Q1及复放。

### up4_hardware — HOLD
- 输入：`src/RuntimeV4/FreeGSAxisymmetricExecution.jl`；`scripts/runtime_v4_freegs_axisymmetric_runner.py`；`src/RuntimeV4/SourceHardwareInverseRealizationContractV1.jl`；`runs/e/up4_optimizer_actual_handback_20261009_a`；`examples/runtime_v4_freegs_axisymmetric_execution.jl`。
- 消费者：examples/runtime_v4_freegs_axisymmetric_execution.jl -> FreeGSAxisymmetricExecution::execute_freegs_axisymmetric_screen(capture_control_result=true) -> freegs_optimized_coil_current_state -> same-candidate same-current forward
- 剩余门：44/44真实优化调用及handback已产生，但0.895864s资源头缺口使运行resource_interruption、零信用；硬件物理约束/完整工程反馈未完成。
- 下一条件：运行环境负责人先验证具体采样修复；capture/handback/same-current forward短检，再完整原A和新进程B。

### up4_reference — HOLD
- 输入：`runs/e/up4_mast_efm_inputs_20261001_r6`；`runs/e/up4_mast_ayc_inputs_20261001_r6`；`src/RuntimeV4/FreeGSAxisymmetricExecution.jl`；`test/UP4ReferenceActualConsumerV1/consume_actual_reference.py`；`benchmarks/reference_validation_v1/reference_adapter.py`；`benchmarks/reference_validation_v1/level1_error_adapter.py`；`benchmarks/reference_validation_v1/thomson_source_response_v1.py`。
- 消费者：existing consume_actual_reference.py -> reference_adapter/level1_error_adapter/thomson_source_response_v1 (source diagnostic only); full inverse G1/G2/G3(theta) -> common execute_freegs_axisymmetric_screen/forward -> heldout consumer remains to implement/connect
- 剩余门：第一方MAST极性/匝数join、Thomson校准与误差语义typed_absent；原数据下载不等于GO，不可用默认0或软件候选声明代替实测来源。
- 下一条件：先短检真实source loader和当前所需输入；旧source consumer的STATIC_INPUTS含缺失历史doc，先精确消除该无关前置而不削弱数据/误差语义。来源/维度GO后接真实theta优化、三Genome同链forward、识别/盲留出与复放；当前源码不提供完整inverse。

### runtime — HOLD
- 输入：`scripts/run_bounded_check.py`；`test/RuntimeV4/InHouseG1G2Q1SolverV1/run_serial_acceptance.py`；`test/RuntimeV4/InHouseG1G2Q1SolverV1/test_serial_supervisor_static.py`；`tmp/monotonic_resource_coverage_owned_20261009/resume_initial_sample/resume_initial_sample.patch`。
- 消费者：existing bounded runner -> UP2/UP3/UP4 actual consumers
- 剩余门：有界运行器保留4 GiB与完整采样/清理门；最新full17的674.67秒采样缺口原因未证，不能用进程峰值或退出记录补全资源证明。
- 下一条件：修具体FakeJob fixture并在原测试复测；现有runner真实立即退出/启动资源短检通过才集成，不新建监控框架。

## 未完成正式门

原验收条款保留；已完成的局部实现从执行步骤中移除。完整接口、单位、生产者/消费者和角色定义见机器清单。

<a id="up2-01"></a>
### UP2-01 声明驱动的物理方程编译

- 前置：UP1-04。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 复用已通过的 DCCE 静态、离散时间、source-bound BE MMS 与耦合双场能力；逐项核对生产 compiler/package 的实际接线及支持范围，不重复实现已完成 lowering。
  - 补齐至少两个未知合法组合和一个预先留出组合经同一生产入口触发真实 residual/solver 的完整证据；保留适用域、单位、边界、稀疏结构及导数元数据。
  - 对尚缺执行器、闭合或边界的声明明确延期；完成原消费者聚合及独立复核后再评 UP2-01 整体验收。
- 原验收条款：
  - 未知合法组合能编成真实残差；不检查整棵 AST 是否等于 fixture。
  - 缺算子执行器、闭合或边界明确延期；无 name/family/ID 路由。
  - 至少两个合法组合和一个预先留出组合从统一入口触发真实 residual/solver；固定七算子、固定六节点或 Python oracle 不能充当一般能力完成。

<a id="up2-02"></a>
### UP2-02 空间物化、离散组装与一般入口

- 前置：UP2-01。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 按本单接口表一次接通真实输入、状态/几何映射、适用物理律、R/J和现有消费者：solver。
  - 加载实际入口；同候选变化状态的一次真实R和线性步；单位/维度/索引/DOF；改动列FD；准备耗时与峰值内存。失败须给具体原因和对应修改后才可长跑。
  - 短检全部通过后再执行原完整A/B；复用仍适用的合格证据，不因无关文件变化重跑。
- 原验收条款：
  - 变系数/边界/区域连接变化无需改代码；至少一项留出声明执行。
  - MMS 的解误差、残差、积分守恒、网格/时间细化各自通过冻结门。
  - 网格、维数、场数和边界适用性与声明一致，真实调用和求解值可核验，错误边界或缺区域不能被静默删除。

<a id="up2-03"></a>
### UP2-03 拓扑传递与外部区域闭合

- 前置：UP2-02、UP2-03-CROSS-MESH-RUNTIME。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 实现重网格/分裂合并后的守恒投影，约束 divB、正性和规范条件，无法同时满足时返回诊断。
  - 实现一条明确适用的外域路径，如真空/导体域加远场截断；源/电路回流由 G3 明确给出。
  - 对静态设计拓扑编辑和物理拓扑事件分别验证，禁止把数值重映射当磁重联物理。
  - 把已修复的 cross-mesh runtime 接到实际 candidate edit/时间演化 consumer，保留拓扑前后守恒和候选身份；禁止只 import 未调用。
- 原验收条款：
  - 转移前后总量差在冻结容差内；场约束与局部误差通过。
  - 远场截断/外域网格细化敏感性通过；删外域或漏回流负控不得获信用。
  - 生产入口实际发生转移并被下游求解消费，完整新旧网格状态、误差和约束负例可复放；有限 1D slice 不替代全部适用拓扑要求。

<a id="up2-04"></a>
### UP2-04 耦合求解、约束与集成

- 前置：UP2-03、UP2-04-PHYSICS-CLOSURE-DIAGNOSTIC、UP2-04-CLOSURE-REPAIR-PREC。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 按本单接口表一次接通真实输入、状态/几何映射、适用物理律、R/J和现有消费者：pressure_topology, current_topology, B_out, K_outer, return_current_path, solver, runtime。
  - 加载实际入口；同候选变化状态的一次真实R和线性步；单位/维度/索引/DOF；改动列FD；准备耗时与峰值内存。失败须给具体原因和对应修改后才可长跑。
  - 短检全部通过后再执行原完整A/B；复用仍适用的合格证据，不因无关文件变化重跑。
- 原验收条款：
  - 所有强耦合残差和守恒同时通过；一轮顺序后处理不能算闭环。
  - 故意错误 Jacobian、缺初值、停滞与约束失败被正确识别。
  - 同入口求解、守恒、网格一致性均按冻结容差通过；W24 iteration_limit 与 N1 负观测阶未解不能声称物理链跑通。

<a id="up2-05"></a>
### UP2-05 成熟物理模块及 backend 能力登记

- 前置：UP2-04。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 先接可验证的扩散/电磁/电路/热/弹性模块，逐项登记输入输出、边界、时间、材料及误差范围。
  - FreeGS/DESC 保留适用域适配器；FUSE 可作为集成参考/后端而非任意拓扑总入口。
  - 为 transport/kinetic/burn/loss 等尚缺模块列出明确模型、接口、数据/资源与 UP6 拆单触发条件。
  - 按完整目标登记并接入真实 provider，对每个 required obligation 明确实现、适用域、输入和证据 producer；bridge_ready 不算求解能力。
- 原验收条款：
  - 每个 claimed module 有组件执行与负例；仅安装包或 bridge_ready 不能记 provider 证据。
  - 删除某 provider 后完整路由返回具体缺口，不能降级到隐藏族模板。
  - 至少一个生产入口真实调起所需 provider 并由下游消费返回值；缺 transport/burn/stability 等适用能力时保留未完成项并派单。

<a id="up3-01"></a>
### UP3-01 自动组合执行矩阵

- 前置：UP2-05。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 复用已通过的 FV A/B、stale-route 因果负例和 Q1 targeted dispatch；先验证队列临时对象释放后的完整负控，不改变 screen-only 安全结果合同。
  - 定位并修复完整运行的资源审计停顿后，执行受影响的短检查，再运行原完整文件/17类 Q1 消费者及新进程复放；保留此前 OOM、测试失败和采样缺口。
  - 将两类合法组合、预先留出及同链反馈结果纳入统一执行矩阵和独立聚合；全部原验收条款齐备才改变任务状态。
- 原验收条款：
  - 同一入口自动生成联合系统，无专门手写候选驱动或完整方程模板。
  - 每个声明支持组合有真实结果与守恒账本；未支持组合明确延期。
  - 两组合法组合及其耦合反馈有实际数值结果；provider/solver 全零计数不能通过执行能力门。

<a id="up3-02"></a>
### UP3-02 留出组合与通用性反证测试

- 前置：UP3-01。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 按本单接口表一次接通真实输入、状态/几何映射、适用物理律、R/J和现有消费者：up3。
  - 加载实际入口；同候选变化状态的一次真实R和线性步；单位/维度/索引/DOF；改动列FD；准备耗时与峰值内存。失败须给具体原因和对应修改后才可长跑。
  - 短检全部通过后再执行原完整A/B；复用仍适用的合格证据，不因无关文件变化重跑。
- 原验收条款：
  - 通过配置无 candidate-specific 源码补丁；拒绝负例的原因可追溯。
  - UP3 acceptance 对准确 capability scope 生效，未覆盖域保持开放。
  - 留出组合不用家族名分支、专用硬编码残差或降低适用要求即可处理；不支持时明确能力缺口并继续目标。

<a id="up3-03"></a>
### UP3-03 可选的受验证基降维

- 前置：UP3-02。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 先分析规范零空间和可识别性，再选择谱基/POD/约束投影，报告离线与在线成本。
  - 加入守恒/约束保留、误差估计、OOD 和拓扑变化失效协议。
  - 与未参与构基的高维解比较；不收敛或新拓扑时回退完整执行。
- 原验收条款：
  - 精度和守恒达到冻结误差门，速度收益扣除构基成本。
  - ROM 不能填补闭合/provider缺口，不能单独授予最终证据。

<a id="up4-01"></a>
### UP4-01 源与硬件的逆向 realization

- 前置：UP3-02。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 按本单接口表一次接通真实输入、状态/几何映射、适用物理律、R/J和现有消费者：up4_hardware, runtime。
  - 加载实际入口；同候选变化状态的一次真实R和线性步；单位/维度/索引/DOF；改动列FD；准备耗时与峰值内存。失败须给具体原因和对应修改后才可长跑。
  - 短检全部通过后再执行原完整A/B；复用仍适用的合格证据，不因无关文件变化重跑。
- 原验收条款：
  - 至少一项候选绑定逆设计实际执行并形成硬件参数与误差证据。
  - 故意不可实现的目标不能被免费源/无限电流等默认值通过。
  - 有实际优化迭代、源实现误差与硬件约束结果；prepared_not_measured 或只有合同测试不算逆实现。

<a id="up4-02"></a>
### UP4-02 热、材料、结构与控制回代

- 前置：UP4-01。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 按本单接口表一次接通真实输入、状态/几何映射、适用物理律、R/J和现有消费者：up4_hardware。
  - 加载实际入口；同候选变化状态的一次真实R和线性步；单位/维度/索引/DOF；改动列FD；准备耗时与峰值内存。失败须给具体原因和对应修改后才可长跑。
  - 短检全部通过后再执行原完整A/B；复用仍适用的合格证据，不因无关文件变化重跑。
- 原验收条款：
  - 闭环误差、耦合残差、守恒和材料/温度/应力门同时成立。
  - 去掉冷却/电源限制/反馈边的负例能触发失败；未验证数据不默认安全。
  - component_load 与各适用反馈有真实 producer，不能以 reduced SI screen 或 component_load=false 接受整机工程。

<a id="up4-03"></a>
### UP4-03 真实参考表示与隐参逆恢复

- 前置：UP4-02、UP4-03-REFERENCE-DATA、UP4-03-REFERENCE-VALIDATION-PREC。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 按本单接口表一次接通真实输入、状态/几何映射、适用物理律、R/J和现有消费者：up4_reference。
  - 加载实际入口；同候选变化状态的一次真实R和线性步；单位/维度/索引/DOF；改动列FD；准备耗时与峰值内存。失败须给具体原因和对应修改后才可长跑。
  - 短检全部通过后再执行原完整A/B；复用仍适用的合格证据，不因无关文件变化重跑。
- 原验收条款：
  - 真实来源、模型适用性、识别和留出全部有实证；参数回收不靠答案泄漏。
  - 非唯一时报告可辨识组合/区间，不宣称精确恢复全部参数。
  - 每个参考有观测→反演轨迹→三层 Genome→同链预测→误差/UQ/留出结果的完整证据；Genome 缺失或只能专用脚本读取不能通过。
  - ITER 500 MW/50 MW/Q10 是设计基准且不发电，不当净电实测正例；实测、设计、外部数值、数据缺失四类信用分别报告。

<a id="up4-04"></a>
### UP4-04 逆实现闭环集成验收

- 前置：UP4-03。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 将需求→设计→实际源→主物理→工程回代串入同一版本化执行计划和检查点。
  - 新鲜运行并检查各阶段 candidate/scenario/input/provider 哈希贯通。
  - 审查外域、控制、热和实现误差是否真正回传，记录剩余整装物理义务。
  - 把参考反演和全新候选统一接入 package→compiler→provider/solve→realization→engineering→VVUQ 的公共执行器，mission 只决定适用门，不按装置名绕门。
- 原验收条款：
  - 不是只存在多个独立脚本；同一输入可重建闭环及其失败恢复。
  - 有限模块闭环验收不抵消尚缺 transport/burn/稳定性或完整整装义务。
  - 参考和新候选走同一 gate 逻辑，至少一次 G1/G2/G3 修改分别触发真实下游变化、身份重建及负控制；集成链在新进程可复放。

<a id="up5-01"></a>
### UP5-01 条件 e-graph 接入

- 前置：UP4-04。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 先连接保守规范化和有限条件等价去重；子表达式 congruence 扩展需逐条规则验证。
  - 条件包含单位、域、边界、时序、效应和闭合；浮点/连续/离散等价作用域分开。
  - 记录 ruleset/order/budget/trace 与 incomplete 状态，禁止未饱和即宣称不等价。
  - 将条件 e-graph 的证明、假设和重写结果实际传入候选生成与物理执行，保留不确定条件拒绝和等价去重。
- 原验收条款：
  - 每条合并可独立重放，条件不成立不合并；表达式改写不自动转移求解证据。
  - 同配置确定性重放；有限预算不同顺序不强求同闭包。
  - 证明与 consumer 对同一候选和假设版本一致，结构合同测试不能替代运行中有条件重写行为。

<a id="up5-02"></a>
### UP5-02 丰富 typed edits 与物理反馈

- 前置：UP5-01。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 实现 G1算子/closure、G2域连接/基阶/几何、G3源网络/材料/控制的合法编辑；每个新物理对象重建身份。
  - 把残差定位、约束敏感度、实现误差、热/供能瓶颈作为编辑/预算反馈；缺provider单列执行工作。
  - 实现可恢复 QD、失败前沿和渐进 MCTS，先有界真实循环，再考虑代理/GFlowNet。
  - 把结构搜索候选接到同一真实正向和工程 evaluator，数值/物理失败进入正确反馈分支；至少各执行一次 G1/G2/G3 非纯标签结构 edit。
- 原验收条款：
  - 至少分别有 G1/G2/G3 编辑引起可观察的执行/反馈变化，非只改常数或标签。
  - 搜索提议与物理/晋升 authority 隔离，失败不被无证据永久剪枝。
  - 真实 solve/mesh/provider 预算与调用非零，候选值变化和下游约束可核验；只使用 surrogate 或固定 manufactured fitness 不算发现闭环。

<a id="up5-03"></a>
### UP5-03 有界比较 campaign 后扩容

- 前置：UP5-02。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 执行同预算基线/增强搜索，分别计 proposal、语义结构、可执行输入和硬门通过数。
  - 比较新可达能力域、单位实际计算成本收益与假阴性，审计休眠恢复和严格合并。
  - 若缺provider或数值失败主导，暂停扩容转派相应执行修复；可用结果达门后逐档增预算。
  - 先用冻结预算比较实际可运行的小型搜索 campaign，再扩容；保留全部失败、重放种子及未发现可信候选的真实结果。
- 原验收条款：
  - 规模由实际能力收益和资源批准驱动；不把预设50–100cells当无条件先跑要求。
  - 真实物理反馈闭环、证据身份、复放均通过，原父目标仍独立记账。
  - 不能以候选数量、哈希唯一或一次 screen 通过宣布原创净能装置；搜索闭环运行与科学发现分别验收。

<a id="up6-01"></a>
### UP6-01 补齐整装必需物理和工程覆盖

- 前置：UP5-03。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 对每个候选枚举平衡、动态稳定性、轨道/损失、输运、燃烧/粒子、辐射及适用动理学义务。
  - 枚举外域、加热/电源、冷却、材料/结构、控制故障、燃料循环、转换和厂用电；每个缺口分配具体模型/数据/provider/测试子单。
  - 逐项实现并验证后重走已有组合与闭环协议，不能跳过无法做的项或以新文档代替。
  - 逐项补齐 mission required obligation 的实际 producer 与工程输入；同一 candidate 的 transport/burn/stability、辐射、粒子和能量、材料寿命等适用范围均有来源和闭合。
- 原验收条款：
  - 所有required模型和工程义务候选绑定执行且满足预注册门；不适用项有证据。
  - 若需外部验证资源，具体blocked项保持开放；不得把有限UP4闭环称整装完成。
  - required 门无 unsupported/unknown/typed absent 的伪 pass，局部屏幕证据只供排查和预算，不直接晋升。

<a id="up6-02"></a>
### UP6-02 独立 VVUQ 与整装净输出

- 前置：UP6-01。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 区分verification、validation、model discrepancy与参数不确定性；与独立实现/数据比较并传播。
  - 计算周期净输出及预注册保守界，包含储能变化、所有供能和辅助损耗，无漏算或重复计能。
  - 对全部required场景核验，来源不足或区间跨零保持unknown/失败。
  - 实现全周期站级净输出 producer：冻结站点边界，接入全部适用输入/辅助系统/储能/转换效率/损失，生成时间积分与不确定性；终局 ledger 实际消费。
- 原验收条款：
  - 有效独立证据及数值协议实际通过；更换线性求解算法不算独立物理验证。
  - 候选净输出在冻结不确定性协议下满足正值门。
  - 存在实际数值 producer 和独立验证，完整周期净输出在冻结不确定性协议下通过保守界；Q>1、字段存在或单次瞬时正值不够。

<a id="up6-03"></a>
### UP6-03 原创性、独立复放与父目标关账

- 前置：UP6-02。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 独立审查机制/结构/行为及外部文献相似性，记录检索日期、范围和局限。
  - 由不同执行者在新鲜环境复放全部关键命令并审查数据/身份/退出码。
  - 逐条R01–R10关账，最终authority判定claim ceiling与候选数；未过则返回明确开放项。
  - 把实际 VVUQ、净输出、原创检索和新鲜复放证据接入 promotion/最终 authority；实现 reserved_not_implemented 路径并用缺证据负例验证 fail closed。
- 原验收条款：
  - 至少一个新候选同时通过所有适用最终物理、工程、净输出、验证与原创性门。
  - 只有此时可关父目标；L4不声称已建造并实测正净输出。
  - 同一全新候选通过全部 R01–R10 和 required 门才父 Goal complete；L4 计算设计结果与 L5 建造实测分开，不承诺绝对全球原创或固定发现日期。

<a id="up2-04-closure-repair-prec"></a>
### UP2-04-CLOSURE-REPAIR-PREC pressure/current 与外部闭合的实际数值修复

- 前置：UP2-04-PHYSICS-CLOSURE-DIAGNOSTIC。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 按本单接口表一次接通真实输入、状态/几何映射、适用物理律、R/J和现有消费者：pressure_topology, current_topology, B_out, K_outer, return_current_path。
  - 加载实际入口；同候选变化状态的一次真实R和线性步；单位/维度/索引/DOF；改动列FD；准备耗时与峰值内存。失败须给具体原因和对应修改后才可长跑。
  - 短检全部通过后再执行原完整A/B；复用仍适用的合格证据，不因无关文件变化重跑。
- 原验收条款：
  - 有实际代码/输入变化及被数值执行消费的结果；预注册 residual/conservation/refinement 门通过才授相应有限数值信用。
  - 缺真实外部输入或闭合仍不成立时保留失败，不能接受“修复完成”；即使局部门通过，正式生产求解和整机物理仍由 UP2-04/UP6 验收。

<a id="up4-03-reference-validation-prec"></a>
### UP4-03-REFERENCE-VALIDATION-PREC 参考观测单位、shape 和 uncertainty 的真实闭合

- 前置：UP4-03-REFERENCE-DATA。
- 状态：HOLD；尚未通过完整正式门。
- 剩余执行：
  - 按本单接口表一次接通真实输入、状态/几何映射、适用物理律、R/J和现有消费者：up4_reference。
  - 加载实际入口；同候选变化状态的一次真实R和线性步；单位/维度/索引/DOF；改动列FD；准备耗时与峰值内存。失败须给具体原因和对应修改后才可长跑。
  - 短检全部通过后再执行原完整A/B；复用仍适用的合格证据，不因无关文件变化重跑。
- 原验收条款：
  - 实际数据/适配器可复核且必要单位、维度和 uncertainty 缺口已闭合；只有 2+2 切分或文档存在不自动满足已冻结统计门。
  - 任何未取得数据仍 typed_absent 并列出需要的增量；本单不声称 B07B 反演完成或三层 Genome 已通过盲留出。

## 已接受依赖索引

仅保留依赖锚点与原范围链接；[原始条款](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md)已迁到实现目录。此前已缺失的21项原件和恢复ZIP不由摘要补足；实际消费者需要原件时继续 HOLD。

<a id="up0-01"></a>
### UP0-01

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up0-01)；无活动执行步骤。

<a id="up0-02"></a>
### UP0-02

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up0-02)；无活动执行步骤。

<a id="up1-01"></a>
### UP1-01

- 范围：g1_typed_mechanism_mimo_closure_candidate_owned_structural_contract。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-01)；无活动执行步骤。

<a id="up1-02"></a>
### UP1-02

- 范围：axis_aligned_rational_3d_g2_structural_contract。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-02)；无活动执行步骤。

<a id="up1-03"></a>
### UP1-03

- 范围：g3_structural_resource_control_fault_and_standalone_feedback_contract。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-03)；无活动执行步骤。

<a id="up1-04a"></a>
### UP1-04A

- 范围：additive_v5_shared_entry_and_structural_same_candidate_join。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a)；无活动执行步骤。

<a id="up2-01-g1-diffusion-v1"></a>
### UP2-01-G1-DIFFUSION-V1

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up2-01-g1-diffusion-v1)；无活动执行步骤。

<a id="up2-01-g2-metric-boundary-v1"></a>
### UP2-01-G2-METRIC-BOUNDARY-V1

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up2-01-g2-metric-boundary-v1)；无活动执行步骤。

<a id="up2-01-g3-source-feedback-v1"></a>
### UP2-01-G3-SOURCE-FEEDBACK-V1

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up2-01-g3-source-feedback-v1)；无活动执行步骤。

<a id="up1-04a-vnext"></a>
### UP1-04A-VNEXT

- 范围：local_source_and_declaration_bound_T1_actual_Gridap_three_level_software_only。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext)；无活动执行步骤。

<a id="up1-04a-vnext-parent-baseline-bind-prec"></a>
### UP1-04A-VNEXT-PARENT-BASELINE-BIND-PREC

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-parent-baseline-bind-prec)；无活动执行步骤。

<a id="up1-04a-vnext-g3-realization-edit-prec"></a>
### UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-g3-realization-edit-prec)；无活动执行步骤。

<a id="up1-04a-vnext-g3-control-edit-prec"></a>
### UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-g3-control-edit-prec)；无活动执行步骤。

<a id="up1-04a-vnext-t0"></a>
### UP1-04A-VNEXT-T0

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-t0)；无活动执行步骤。

<a id="up1-04a-vnext-g3-binding-edit-prec"></a>
### UP1-04A-VNEXT-G3-BINDING-EDIT-PREC

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-g3-binding-edit-prec)；无活动执行步骤。

<a id="up1-04a-vnext-t0-authority-recheck-prec"></a>
### UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-t0-authority-recheck-prec)；无活动执行步骤。

<a id="up1-04a-vnext-t1"></a>
### UP1-04A-VNEXT-T1

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-t1)；无活动执行步骤。

<a id="up2-00"></a>
### UP2-00

- 范围：contract_only_current_source_schema_validator_all50_full_original_A_B。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up2-00)；无活动执行步骤。

<a id="up1-04b"></a>
### UP1-04B

- 范围：B00_F0_F5_and_all50_B04_source_schema_archive_two_process_software_gate。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04b)；无活动执行步骤。

<a id="up1-04"></a>
### UP1-04

- 范围：current_candidate_G1_G2_G3_public_refs_four_axes_exact_identity_migration_package_consumer_join_software_only。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04)；无活动执行步骤。

<a id="up1-04a-vnext-t1-diagnostic"></a>
### UP1-04A-VNEXT-T1-DIAGNOSTIC

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-t1-diagnostic)；无活动执行步骤。

<a id="up2-03-cross-mesh-runtime"></a>
### UP2-03-CROSS-MESH-RUNTIME

- 范围：candidate_bound_two_to_four_cross_mesh_transfer_and_one_dimensional_diffusion_runtime。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up2-03-cross-mesh-runtime)；无活动执行步骤。

<a id="up2-04-physics-closure-diagnostic"></a>
### UP2-04-PHYSICS-CLOSURE-DIAGNOSTIC

- 范围：hash_bound_fail_closed_w24_n1_causal_diagnostic。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up2-04-physics-closure-diagnostic)；无活动执行步骤。

<a id="up4-03-reference-data"></a>
### UP4-03-REFERENCE-DATA

- 范围：two_shot_raw_reference_arrays_provenance_validation_and_preregistered_inverse_protocol。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up4-03-reference-data)；无活动执行步骤。

<a id="up1-04a-vnext-t2-source-witness-prec"></a>
### UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC

- 范围：历史原记录的有限软件/合同范围。
- [原条款及证据路径](../implementation/IMPLEMENTED-STATE-20261019/accepted_contracts.md#up1-04a-vnext-t2-source-witness-prec)；无活动执行步骤。

<a id="up1-04a-vnext-t2"></a>
## UP1-04A-VNEXT-T2（历史，已取消）

原独立 T2 未接受且剩余专项已取消。保留兼容合同和摘要，不派发旧控制器、Git生命周期、分片或历史hash重绑。
