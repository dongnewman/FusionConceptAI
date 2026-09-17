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

两套 genome 必须使用独立 seed 和独立 hash。

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
- 无效、不可控、不可观状态删除；
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