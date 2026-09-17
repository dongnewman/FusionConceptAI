# G3 实现—控制 Genome 升级规划（拟议）

> 统一声明：本文新增的 V2/V5、profile、migration receipt、compiler 和 gate 均为拟议；UP0–UP2 的合同、输入输出、阈值和身份规则必须先冻结，再进入 UP3–UP6。四个版本轴分别是 payload schema version、canonicalization/hash profile version、grammar/capability applicability profile version、execution/evidence receipt version；它们不能互相替代。V1/V4 历史哈希和证据保持不变。

可以把“实现—控制”拆成两个独立但通过端口绑定的 genome：

\[ \mathcal G_R=(P,M,N,A,W,\Theta_R) \]\[ \mathcal G_C=(Y,\hat X,K,H,S,\Theta_C) \]

其中：

- \(P\)：物理功能端口及其绑定；
- \(M\)：材料与属性场；
- \(N\)：导体、冷却、支撑、供能等嵌入式网络；
- \(A\)：可实现源的空间基；
- \(W\)：制造、装配和维护程序；
- \(Y\)：传感器；
- \(\hat X\)：状态估计器；
- \(K\)：反馈策略；
- \(H\)：混合状态机；
- \(S\)：安全与保护；
- \(\Theta_R,\Theta_C\)：连续参数。

两套 genome 必须使用独立 seed 和独立 hash。现有 `RealizationControlGenomeV4` 不能直接改名或原地升级为两套 V5；拟议 `RealizationGenomeV5`、`ControlGenomeV5` 和 `CoupledRealizationControlBindingV2` 必须通过逐字段、逐引用 migration receipt 从 V4 生成新的 candidate identity，并重新执行受影响的上游验证。

## 一、RealizationGenome

### 1. 输入不是“要几个线圈”，而是功能端口

场—几何层给出一个目标连续源：

\[ q^\star(x,t). \]

RealizationGenome 需要构造若干可控制的空间源基：

\[ q_{\mathrm{real}}(x,t) = \sum_{i=1}^{n_a} a_i(x;\theta_R)\,u_i(t). \]

其中：

- \(a_i(x)\)：第 \(i\) 个物理通道能产生的空间作用；
- \(u_i(t)\)：控制层给出的时间命令。

端口绑定基因：

```
FunctionalPortBindingGene
├─ demand_port_ref
├─ resource_kind
├─ source_basis_refs[]
├─ required_output_signature
├─ unit_signature
├─ spatial_support_requirement
├─ temporal_bandwidth_requirement
├─ amplitude_requirement
├─ independence_group
└─ approximation_tolerance
```

实现误差是硬门：

\[ \epsilon_{\mathrm{source}} = \frac{ \left\|q^\star-\sum_i a_i u_i\right\|_W }{ \|q^\star\|_W+\epsilon }. \]

不能通过后续控制得分补偿源场根本无法实现。

### 2. 材料基因

材料不能直接把强度、导热率等数值当作自由优化变量，否则搜索器会“发明无限强材料”。

```
MaterialAssignmentGene
├─ material_dataset_ref
├─ dataset_version
├─ phase_field_ref
├─ composition_fraction_genes[]
├─ orientation_field_ref
├─ operating_domain
├─ joining_compatibility_refs[]
├─ irradiation_state_ref
└─ uncertainty_model_ref
```

规则：

- 已验证材料属性必须来自版本化数据集；
- composition 可以在数据集允许的范围内变异；
- 超出数据域时状态为 `unknown_material_property`；
- 假说材料可以保留，但不得获得工程通过信用。

连续材料分布可以写成：

\[ p(x,T,d) = \sum_m \chi_m(x)\, p_m(T,d;\text{dataset}), \]

其中 \(d\) 是损伤或剂量状态。

### 3. 嵌入式网络基因

导体、冷却、结构、供电和数据通道统一表示成嵌入式有向多图：

```
EmbeddedNetworkGene
├─ network_id
├─ transported_account
├─ manifold_dimension
├─ nodes[]
├─ edges[]
├─ material_refs[]
├─ source_sink_ports[]
├─ capacity_constraints[]
└─ fault_isolation_groups[]
```

每条边：

```
NetworkEdgeGene
├─ source_node
├─ target_node
├─ centerline_program
├─ cross_section_program
├─ material_ref
├─ length_scale
├─ capacity_gene
├─ resistance_or_impedance_model
├─ thermal_coupling_refs[]
├─ support_refs[]
└─ isolation_switch_ref
```

例如一条通道可以输运：

- 电流；
- 冷却剂质量；
- 热；
- 粒子；  
    -机械载荷；
- 信息；
- 电功率。

“线圈”“冷却管”“支撑梁”不是基因类别，而是网络经过空间 realization 后得到的解释。

网络边不能用一条泛化方程覆盖所有资源：电流、电压、冷却剂质量/能量、热、机械载荷、粒子和信息必须各自绑定 typed account、constitutive law、单位、方向、容量、边界和时间语义；跨资源耦合只能通过显式 transfer/损耗合同发生。没有对应 law 的资源边记录具体 `match_reason` 并进入 `deferred`/`terminal_deferred`；最终 authority 才能依据证据分类 `unsupported`。

### 4. 截面和中心线如何量化

中心线仍使用可变长度基函数程序：

\[ r_e(s) = r_{e,0} + \sum_j c_{ej}\psi_j(s). \]

截面使用正值映射：

\[ A_e(s) = A_{\min} + \operatorname{softplus} \left( \sum_k a_{ek}\varphi_k(s) \right). \]

对应基因保存：

- basis family；
- 活跃模态索引；
- normalized coefficient；  
    -最小曲率半径；
- 最小截面；
- 最大长宽比；
- 与其他网络的 clearance。

实际长度、曲率、质量、电阻和压降是 phenotype。

### 5. 供能和资源账本

每个 actuator 必须连接到真实资源网络：

```
ResourceSupplyGene
├─ resource_kind
├─ producer_refs[]
├─ storage_refs[]
├─ consumer_refs[]
├─ conversion_operator
├─ maximum_power
├─ stored_energy
├─ ramp_rate
├─ duty_cycle
├─ recovery_time
└─ efficiency_dataset_ref
```

必须满足：

\[ \dot E_{\mathrm{store}} = P_{\mathrm{in}} - P_{\mathrm{actuator}} - P_{\mathrm{loss}}. \]

控制器不能命令超过：

- 峰值功率；
- 累积能量；
- ramp rate；
- 占空比；
- 冷却恢复能力。

### 6. 制造、装配与维护基因

```
ManufacturingProgramGene
├─ process_operator_sequence[]
├─ material_input_refs[]
├─ minimum_feature_size
├─ tolerance_model
├─ joining_operations[]
├─ inspection_operations[]
├─ assembly_order_constraints[]
├─ access_volume_requirements[]
└─ replaceable_module_partition[]
```

允许的 process operator 可以包括：

- deform；
- wind；
- deposit；
- remove；
- join；
- heat-treat；
- inspect；
- assemble；
- seal。

它们是制造操作原语，不是装置模板。

如果需要假说制造方法，同样使用 `typed_process_hole`，并产生外部工艺验证义务。

## 二、ControlGenome

### 1. SensorGene

传感器基因描述“测什么、在哪里测、以什么动态测”：

\[ y_i(t_k) = \mathcal H_i[z(t_k-\tau_i)] +b_i+\eta_i. \]

```
SensorGene
├─ observable_expression_ref
├─ support_or_location_field
├─ sampling_period
├─ latency
├─ bandwidth
├─ range
├─ resolution
├─ noise_covariance
├─ bias_drift_model
├─ dropout_model
└─ power_and_data_cost
```

传感器位置可以由连续 placement field 产生，再 materialize 为有限个采样位置。

### 2. ActuatorDynamicsGene

控制命令不能直接瞬时作用于物理状态：

\[ \tau_i\dot u_i = \operatorname{sat}_{[u_{\min},u_{\max}]} (v_i)-u_i. \]

并且：

\[ |\dot u_i|\le r_i. \]

```
ActuatorDynamicsGene
├─ source_basis_ref
├─ input_unit
├─ output_unit
├─ lower_limit
├─ upper_limit
├─ slew_rate
├─ time_constant
├─ dead_time
├─ hysteresis_model
├─ duty_cycle
├─ failure_modes[]
└─ resource_supply_ref
```

容量、延迟、饱和和故障必须进入与主物理相同的 coupled residual，而不是求解后附加一个评分。

### 3. EstimatorGenome

估计器可以先采用有界状态空间形式：

\[ \dot x_e = A_ex_e+B_ey, \]\[ \hat z = C_ex_e+D_ey. \]

基因包括：

```
EstimatorGene
├─ estimator_state_count
├─ observed_state_refs[]
├─ A_gene
├─ B_gene
├─ C_gene
├─ D_gene
├─ filter_operator_ast
├─ initial_covariance
├─ process_noise_model
└─ observability_requirements
```

矩阵元素不是任意裸浮点数，而是归一化参数。需要稳定的内部动态时可以使用：

\[ A_e = Q-Q^\mathsf T - LL^\mathsf T - \epsilon I, \]

其中拟议 profile 必须声明 `epsilon>0` 的数值范围、单位和与采样时间的关系；参数化稳定只提供连续模型的候选约束。连续时间稳定、离散采样稳定、量化/延迟/饱和下的闭环稳定必须分别验收，不能由该参数化一句话替代。

从表示上保证其对称部分为负定。

### 4. PolicyGenome

最小通用控制器可以写成：

\[ \dot x_c=A_cx_c+B_ce, \]\[ v=C_cx_c+D_ce, \]\[ u= \operatorname{RateLimit} \left[ \operatorname{Saturate}(v) \right]. \]

更复杂控制策略使用 typed control AST：

```
OBSERVE
FILTER
PREDICT
SUBTRACT_REFERENCE
MATRIX_GAIN
INTEGRATE
DIFFERENTIATE
DELAY
GAIN_SCHEDULE
SATURATE
RATE_LIMIT
ALLOCATE_ACTUATORS
OPTIMIZE_BOUNDED_ACTION
```

每个节点都带：

- 输入/输出单位；
- 采样和时间语义；
- 状态维数；
- 依赖传感器；
- 使用的 actuator；
- 最大运算周期；
- 失效后的 fallback。

这比直接枚举 PID、MPC、LQR 名称更底层；这些名称只是 operator program 的后验分类。

### 5. Actuator AllocationGene

当有多个 actuator source basis 时，控制器还要搜索分配矩阵：

\[ u=W_av, \]

并满足：

\[ u_{\min}\le W_av\le u_{\max}. \]

```
AllocationGene
├─ virtual_control_refs[]
├─ actuator_refs[]
├─ sparse_weight_matrix
├─ priority_classes[]
├─ resource_coupling_constraints[]
├─ failure_reallocation_rules[]
└─ condition_number_limit
```

这允许同一机制由完全不同的执行器组合实现。

### 6. 混合状态机

启动、稳态、脉冲、故障和停机不是单一线性控制器能完整表达的。

```
HybridSupervisorGene
├─ modes[]
├─ transition_edges[]
├─ guard_expression_ast
├─ reset_maps[]
├─ allowed_actuators_by_mode[]
├─ entry_actions[]
├─ exit_actions[]
└─ maximum_dwell_time
```

例如：

```
startup
→ acquisition
→ regulated_operation
→ degraded_operation
→ emergency_shutdown
→ passive_safe_state
```

模式名称只是显示信息；真正进入 genome 的是 guard、reset、允许的资源与状态约束。

### 7. 安全与保护基因

安全阈值来自 mission/governance contract，不能由搜索器修改。

ControlGenome 只能搜索：

- 使用什么观测量识别危险；
- 多快动作；
- 切断哪些 actuator；
- 接通哪些耗散、dump 或隔离通道；
- 是否进入被动安全状态。

```
ProtectionGene
├─ immutable_hazard_constraint_refs[]
├─ detection_logic_ast
├─ detection_deadline
├─ protection_actuator_refs[]
├─ action_sequence[]
├─ independent_power_required
├─ fail_safe_state
├─ reset_authority
└─ proof_obligation_refs[]
```

同样，必测故障集合不是 genome。它由外部测试协议固定。否则搜索器会通过删除难以通过的故障来“优化安全性”。

## 三、一个最小联合实例

```
{
  "realization": {
    "source_bases": [
      {
        "source_id": "a0",
        "target_port_ref": "field_source_port_0",
        "network_ref": "n0",
        "capacity": 2.0e6,
        "unit": "A"
      }
    ],
    "networks": [
      {
        "network_id": "n0",
        "transported_account": "electric_current",
        "node_count": 8,
        "edge_count": 10,
        "material_dataset_ref": "material-dataset-hash"
      }
    ]
  },
  "control": {
    "sensors": [
      {
        "sensor_id": "y0",
        "observable_ref": "state_observable_0",
        "sampling_period_s": 0.001,
        "latency_s": 0.002
      }
    ],
    "actuators": [
      {
        "actuator_id": "u0",
        "source_basis_ref": "a0",
        "upper_limit": 1.0,
        "slew_rate_per_s": 50.0,
        "time_constant_s": 0.005
      }
    ],
    "policy": {
      "state_count": 2,
      "operator": "BOUNDED_STATE_SPACE_PROGRAM"
    }
  }
}
```

这仍然只是一份 genome；实际电流路径、应力、温度、控制裕量和故障生存性必须由求解器产生。

## 四、不能作为基因的量

以下只能是 phenotype 或验证结果：

- 峰值应力；
- 最高温度；
- quench hotspot；
- 压降；
- 部件寿命；
- 实际线圈/管道数量；
- 控制稳定裕量；
- 最大状态偏移；
- 故障恢复时间；
- 净电；
- 可用率；
- 维护时间；
- 工程 pass；
- 安全 pass。

否则搜索器可以直接把“最大应力=0”写进 genome。

## 五、Canonical hash

Realization 和 control 需要分别规范化：

- 网络节点重新编号；
- 同类 actuator/sensor 排列归一；
- source basis 的符号和尺度归一；
- 材料 phase label 归一；
- 控制器状态坐标变换归一；
- 相似变换等价的状态空间模型转换成最小 realization；
- 无效、不可控、不可观状态只能在等价约束、观测/可控性证明以及保护/故障状态保留证书通过后删除；否则保留并标记其未决影响；
- mission threshold 和 fault set 排除在可变 genome 之外。

建议使用：

```
functional_binding_hash
material_assignment_hash
embedded_network_hash
manufacturing_program_hash
realization_hash

sensor_layout_hash
estimator_behavior_hash
policy_transfer_hash
hybrid_supervisor_hash
protection_logic_hash
control_hash

coupled_realization_control_hash
```

## 六、建议的 v1 搜索边界

|对象|v1 范围|
|---|---|
|功能端口|1–16|
|材料 phase|1–8|
|嵌入式网络|1–12|
|网络节点总数|4–128|
|网络边总数|3–256|
|actuator source basis|1–32|
|resource supply group|1–16|
|制造操作|1–32|
|sensors|0–32|
|actuators|1–16|
|estimator states|0–32|
|control AST 节点|4–64|
|hybrid modes|1–8|
|transition guards|0–24|
|protection channels|1–8|
|连续参数|不超过 256，稀疏激活|

## 七、接入当前项目

现有代码已经有部分接口，但仍是较窄模板：

- v89 使用固定 component role 和一个简单 bounded-state-feedback 描述；[v89 realization](D:\\006-Programing\\LMC\\outputs\\fusion_concept_ai\\src\\universal_realization_grammar_v89.jl)
- v108 主要枚举四组 PI 增益并跑固定故障场景；[v108 controller overlay](D:\\006-Programing\\LMC\\outputs\\fusion_concept_ai\\src\\dynamic_fault_provider_v108.jl)
- 工程 runtime 已能消费候选绑定材料、几何、故障、热、结构和 quench 数据；[工程求解入口](D:\\006-Programing\\LMC\\outputs\\fusion_concept_ai\\src\\candidate_engineering_multiphysics_runtime_v1.jl)

新的编译链应是：

```
FieldGeometryGenome 的目标连续源
→ RealizationGenome 生成 source basis、材料场和资源网络
→ ControlGenome 生成 sensor–estimator–policy–actuator 闭环
→ 全部控制状态和 actuator dynamics 接入 v68 coupled residual
→ 工程、热工、故障和保护 provider
→ numerical VVUQ
→ 独立验证
```

这时实现—控制 genome 表达的不是“选哪一种现有线圈和控制器”，而是：

> 用什么受材料、资源和制造约束的物理网络近似目标连续源，以及通过什么可观测、有限带宽、饱和且可失效的闭环维持它。

## 八、升级边界：当前能力与拟议 G3 扩展

本节是可执行规划，带有“拟议”前缀的类型和接口尚未实现，不能作为现有工程或控制能力的证明。

当前源码的 `RealizationControlGenomeV4` 已实际保存独立 realization/control seed、`GenomeContractRef`、两个 `TypedOperatorHypergraphV1` 和两个不可变 tuple；构造器检查 seed 独立、深不可变和 canonicalizable。现有 engineering/control/fault contracts 能表达 candidate-bound 的材料/几何/故障/观测/执行依赖和 evidence obligation，但仍是较窄的 admission/overlay；不能据此宣称任意 source、材料热结构闭合、实时控制或可制造装置。v89 的 realization grammar、v108 的 PI/fault overlay 和工程 runtime 都应作为可复用适配器或基准，不应冻结为唯一 G3 语法。

源码依据：`src/Genomes/RealizationControlGenome.jl` 的双图/独立 seed/canonical admission，以及 `src/RuntimeV4/EngineeringControlFaultContracts.jl`、`EngineeringControlFaultExecutionRequestV4.jl` 的 candidate-bound obligation/provider admission。

拟议版本合同：

```text
G3SchemaProfileV2 (拟议)
├─ schema_uri/version/schema_hash
├─ canonicalization_profile/hash
├─ realization_grammar_profile_ref
├─ control_grammar_profile_ref
├─ resource/material/thermal/structural capability declarations
├─ realization_field_count_semantics
├─ network_dof_semantics_ref
└─ migration_policy
```

拟议 `RealizationGenomeV5` 和 `ControlGenomeV5` 应分开 schema/hash，再以 `CoupledRealizationControlBindingV2`（拟议）绑定。迁移收据 `G3MigrationReceiptV2`（拟议）必须记录源/目标 URI、版本、schema/canonicalization hash、seed、graph/payload 映射、未表示字段、独立验证结果和状态。V4 历史 hash、运行 receipt、工程/控制证据永远不改写；变更目标 source、材料、网络、传感器、控制器、故障或资源边界都生成新的 candidate identity，并要求重新执行上游链路。

## 九、G3 语义分工与不可免费实现原则（拟议）

G3 只负责装置资源与控制：

- G1 定义方程、状态、守恒账户、operator effect 和导数/适用域；
- G2 定义空间区域、接口、连续场、离散网格和外部域；
- G3 定义 source basis 的物理网络、材料/热/结构/供能、制造、传感器、估计器、策略、执行器和保护。

G3 输入的目标连续源 (q^\star(x,t)) 必须通过 source capability、幅值/带宽、功率/能量、热/结构和制造约束才能进入 realization。拟议 `SourceRealizationCertificateV2` 需要同时给出目标场、网络 source basis、控制轨迹、加权误差、资源账本、适用域和不确定度。没有这样的可实现证据时，目标场只是 demand，不能被 G3 以任意 actuator 或高分控制器“免费实现”。

材料属性必须引用版本化数据集和 operating domain；超域、未知连接工艺、缺热反馈或无独立故障电源均保留具体 `match_reason` 与 `unknown`/`deferred`/`terminal_deferred`。控制 saturation、slew、delay、dropout、故障与资源容量应作为 coupled residual/执行器状态的一部分；求解后附加的分数不能修复物理 source mismatch 或容量短缺。

## 十、按统一路线的 G3 执行合同（拟议）

### UP0：基线合同

- 输入：`RealizationControlGenomeV4`、两个现有 typed graphs、contract registry、工程/控制/故障 contracts、V4 hash 与历史 receipt。
- 输出：`G3BaselineContractV1`（拟议），列明当前 realization/control 图、独立 seed、资源依赖和未覆盖的热结构/制造/反馈闭环。
- 步骤：冻结 V4 字节/hash；逐节点核对 realization/control graph、payload、contract ref、observation/actuation/fault obligation；把 admission、screen、工程 evidence 分开。
- 正向测试：相同 V4 candidate 可重放相同 realization/control/coupled hashes；seed 相等、graph 不可变或 contract ref 错误按构造器规则拒绝。
- 反向测试：复用外来 candidate hash、把未绑定 actuator 当可用、缺 provider 或缺 fault recovery 的输入必须记录 match reason 并为 gap/deferred；最终 authority 才能依据完整证据分类 `unsupported`。
- 退出门：历史 evidence 不变；当前 G3 只能按实际 provider/receipt 计分，credible count 仍为 0。
- 失败处理：不修改 V4 schema/哈希；将缺口登记为拟议 V5 migration 工作项。

### UP1：三 Genome 合同和最小可执行组件

- 输入：UP0、拟议 G3 schema/profile、最小 source basis、一个资源端口网络、一个 sensor–estimator–policy–actuator 闭环。
- 输出：版本化 realization/control profiles、端口/资源/故障合同、最小 candidate-bound 执行计划（拟议）。
- 步骤：先编译端口单位/能力/资源账本和控制时间语义；复用现有 typed graph 与 ECF obligation；仅验证可执行组件，不宣称制造或闭环物理通过。
- 正向测试：source basis 与 demand port 精确绑定，actuator 有 finite limit/slew/resource ref，sensor 有 sampling/latency/noise，policy 输出经过 allocation 和 protection。
- 反向测试：无源网络的 actuator、功率超额、负容量、未绑定 observation、未声明延迟/故障和图角色错误均 fail closed。
- 退出门：输出带 realization/control/candidate/profile/provider hash；无真实 source/engineering provider 时保持 `screen_only`/`deferred`。
- 失败处理：区分具体 match reason、`unknown`（属性/证据未知）、`numerical_fail` 与 `terminal_deferred`；`unsupported` 只能由最终 authority 依据证据签发。

### UP2：物理编译、空间离散与耦合层的 G3 责任

- 输入：UP1 G3 graph、G1 residual、G2 geometry/mesh、材料属性、资源网络和 source target。
- 输出：source basis assembly、材料热结构与资源账本的耦合输入、sensor/actuator dynamic residual 绑定（拟议）。
- 步骤：将 actuator dynamics、资源供能、热损失、结构载荷和控制状态接入共享 residual；对 source mismatch、容量、温度、应力和保护动作保留逐项 receipt。
- 正向测试：制造 source 回代误差在 tolerance，能量/功率账本闭合，热/结构反馈和有限带宽控制可复现，故障路径在约束内进入安全状态。
- 反向测试：求解后加功率/热/控制分数、瞬时无限 actuator、删除故障场景、无网络回路却声称供能闭合均拒绝。
- 退出门：G1/G2/G3 同一 candidate-bound coupled residual 包含所有声明贡献；否则工程/控制状态保持 `deferred`。
- 失败处理：保留迭代、容量短缺、热/结构超限及退出码；不把控制器局部稳定等同于整机通过。

### UP3：合法组合自动执行

- 输入：通过 UP2 的 source/network/material/control prefixes 和 capability signature。
- 输出：合法 G3 组合的 execution manifests、资源/故障覆盖表和可重放 receipt（拟议）。
- 步骤：沿 canonical prefix DAG 组合网络、材料、制造、sensor、estimator、policy、allocation、protection；任何 G3 变更都生成新 coupled identity 并重新绑定 G1/G2。
- 正向测试：节点重编号、同类 sensor/actuator 重排在 canonicalization 后一致；不同网络拓扑、材料 dataset、policy graph 或 fault set 产生新 hash。
- 反向测试：按 component role/name 猜 capability、把未绑定资源当无限供能、复用旧控制轨迹或制造 receipt 均拒绝。
- 退出门：自动执行只证明组合与资源/控制收据，不授予制造、工程或安全 pass。
- 失败处理：provider 缺失进入 `terminal_deferred`；低保真控制失败保留 failure frontier，不能永久 prune。

### UP4：逆向源硬件 realization、供能热结构反馈

- 输入：UP3 连续目标源、G2 几何/场 trace、材料数据库、网络候选、制造/维护约束和保护要求。
- 输出：可制造 source realization、供能/冷却/支撑网络、热结构反馈闭环和回代误差/不确定度（拟议）。
- 步骤：求解有限 source basis 的逆问题；检查独立性、功率/能量、ramp/duty、clearance、材料 operating domain、热损和结构寿命；将温度/变形/损伤反馈回 source 与控制 residual；执行故障与保护场景。
- 正向测试：多起点逆解可辨识、source 回代与目标场误差达标、资源账本闭合、热结构反馈稳定、故障恢复在 deadline 内完成，并可由独立 provider 重放。
- 反向测试：欠秩 source basis、无供能/冷却/返回路径、材料超域、仅仿真控制稳定或控制评分抵消 source mismatch 均记录具体 match reason 并进入相应失败账本；最终 authority 才能依据证据分类 `unsupported`。
- 退出门：仅有完整 realization、资源、热结构、制造、控制和 fault receipt 才能进入装置候选；局部 pass 不升级为整机 pass。
- 失败处理：不可识别按可识别组合与误差适用域记 `unknown` 并置 `terminal_deferred`，能力缺口保留具体 match reason，数值不收敛记 `numerical_fail`，未执行记 `not_executed`；`unsupported` 只能由最终 authority 依据证据签发。

### UP5：条件 e-graph 与扩大演化搜索

- 输入：通过 UP4 的 G3 graphs、material/resource domains、fault contracts 和条件 rewrite checker。
- 输出：网络/控制程序 lineage、可重放 rewrite trace、按资源/安全/实现能力分层的搜索前沿（拟议）。
- 步骤：只做保端口、保单位、保资源账本、保故障覆盖的条件重写；交替离散网络编辑与连续控制/几何优化；对每次改变重建 G1/G2/G3 identity 和上游 receipts。
- 正向测试：等价控制状态坐标变换、网络同构和合法 policy rewrite 保持输入输出/故障语义；source capability 与热结构约束在重写后仍闭合。
- 反向测试：删除难测故障、增大未声明功率、跳过材料数据域、用 surrogate 排名或 AI 提议冒充 engineering evidence 均拒绝。
- 退出门：搜索只覆盖 profile 声明的网络/控制空间；没有独立 source/热结构/故障证据不能晋级。
- 失败处理：条件不确定为 `unknown`，预算/ provider 不足为 `deferred`，不能签发物理无解证明。

### UP6：整装 R01–R10 的 G3 责任

- 输入：最终三 Genome candidate、硬件 realization、供能/热/结构/控制/故障 artifacts、VVUQ 和独立 replay 环境。
- 输出：G3 独立验收包及与 G1/G2 的边界清晰的 whole-device evidence。
- 步骤：核对 source 回代、材料域、资源账本、制造可达、控制观测性/稳定性、保护与故障恢复、独立 provider 和不确定度；把工程 pass、control pass、安全 pass 分开。
- 正向测试：至少一个候选通过适用的工程、控制、故障和独立验证硬门，所有输出带 candidate/provider/scenario/uncertainty/independence 绑定。
- 反向测试：固定组件模板、合成故障、未闭合供能、单次控制仿真、局部材料数据或文档声明不得满足 R01–R10。
- 退出门：整装要求全部有独立证据；否则 parent goal 仍未完成，credible count 不上调。
- 失败处理：按 `scientific fail`、`program exception`、`human interruption`、`not_executed`、`unknown`、`physical_fail` 和 `deferred` 分账并保留 match reason；`unsupported` 只能由最终 authority 依据证据签发。
