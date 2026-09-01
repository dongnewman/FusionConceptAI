# v4 候选集成、抽象拓扑与一致性编译

## 1. 职责

本模块对应现有链路的“抽象拓扑生成 + 抽象一致性筛选”，但输入不再是一个扁平 topology record，而是三个既有 Genome 的版本化引用或部分前缀。

它负责回答：候选声明了什么区域、状态、算子、场、几何、组件和控制义务；这些声明能否在不使用装置家族标签的情况下被确定地编译。它不回答候选是否物理可行。

## 2. 输入与输出

输入：

- `MissionContractV4`；
- 三个 Genome 的完整对象或部分前缀；
- `GenomeContractRegistryV4`；
- grammar/bounds/compatibility profile；
- 可选 `ProposalEnvelopeV4`。

输出为 `CompiledCandidatePrefixV4`：

```text
candidate_prefix_ref
normalized_regions[]
normalized_interfaces[]
normalized_boundaries[]
state_slots[]
operator_obligations[]
conservation_accounts[]
source_sink_ledger[]
sensor_actuator_paths[]
function_spaces[]
free_and_bound_variables[]
unresolved_nonterminals[]
capability_obligations[]
canonical_hashes
compilation_assessments[]
```

每个字段都必须能追溯到某个 Genome gene 或 mission requirement。编译器不得通过默认 family 模板发明字段。

## 3. 三种 Genome 的组合规则

三种 Genome 不做无约束乘积，而通过 obligation matching 组合：

1. 机制 Genome 声明所需状态、算子、守恒结构、可观测量和因果关系。
2. 场—几何 Genome 声明状态/算子的空间承载、区域、边界、接口、场源表达和基。
3. 实现—控制 Genome 声明哪些真实组件、资源网络、传感器、执行器和控制结构承担这些义务。

组合成功要求：

- 每个 required state 有唯一或明确耦合的空间承载；
- 每个 required operator 有 function space、维度、坐标和边界；
- 每个源/汇进入明确守恒账户；
- 每个执行器输出进入机制或场的消费者；
- 每个闭环控制目标存在观测路径和作用路径；
- alternatives 与 scenarios 的量词明确。

设计 alternatives 使用存在量词：至少一个有限 alternative 可以满足义务。运行、扰动和故障 scenarios 使用全称量词：进入声明 scope 的每个 scenario 都必须被评估，不能挑选有利场景。

## 4. 部分 Genome 与惰性展开

候选前缀允许存在尚未展开的 nonterminal，例如：

```text
required_field_source
required_boundary_realization
required_transport_closure
required_control_observer
```

前缀编译的结果有三类：

- `prefix_consistent`：当前声明无矛盾，且至少存在未排除的完成路径；
- `prefix_incomplete`：一致但仍有 required nonterminal；
- `certificate_candidate`：发现可能永久剪枝的矛盾，交给 Proof Authority 验证。

编译器自身不得直接把 `certificate_candidate` 写成 `proof_pruned`。

## 5. 抽象一致性检查

### 5.1 Schema 与类型

- contract/schema 版本明确；
- 状态、算子和端口类型相容；
- 标量、向量、张量阶数一致；
- 坐标和协/逆变语义明确；
- 离散事件不能连接到未声明 hybrid state。

### 5.2 单位与守恒账户

- 所有数值字段携带单位；
- 接口两侧通量符号相反且账户一致；
- 不存在未声明的粒子、能量、电荷、动量或磁通创造；
- source、sink、reservoir 和 boundary flux 能组成可审计账本；
- 未闭合账户是 required obligation，不能用零值默认为闭合。

### 5.3 图与因果

- 区域和接口 ID 唯一；
- required consumer 可达；
- 无悬空执行器、传感器或未消费 gene；
- 代数环和延迟环被显式标记；
- 控制路径不存在未来信息或未声明测量；
- 自由度、代数约束和边界条件数量可审计。

### 5.4 Capability obligations

编译器生成完整义务签名：

```text
operator
physical_states
source_space / target_space
dimension / coordinates
boundary / interface_relation
time_semantics
required_output
evidence_level
applicability_bounds
```

空 axis 非法且不代表 wildcard。义务只能在后续由 provider manifest 完整匹配。

## 6. 规范化与去重

依次执行：

1. ID 独立的节点/边 canonicalization；
2. 可交换项排序；
3. 对称区域和同构接口规范化；
4. 单位换算到规范单位；
5. 浮点量按合同规定序列化；
6. 生成分层 canonical hash。

结构等价不代表物理等价；只有 `solver_input_hash` 相同才能复用确切求解结果。`semantic_hash` 相同只用于搜索去重或档案聚合。

## 7. 与搜索模块的接口

搜索器只能通过合法 typed edit 修改候选前缀。每个 edit 声明：

- consumes/produces 的 nonterminal；
- 前置类型和语义条件；
- 可能影响的守恒账户和 capability obligation；
- 是否改变三个 Genome 中的哪一个；
- 是否需要重新物化或重新求解。

所有后代必须重新经过本文编译器；搜索器不得缓存一个旧编译结果并套用于发生物理变化的新候选。

## 8. 失败与证据边界

本模块可以报告 schema/type/contract compilation 状态，但不能报告：

- 平衡、稳定性、输运或工程通过；
- 物理装置可行；
- 文献或专利新颖性；
- 求解器不存在意味着物理失败。

## 9. 验收测试

1. 删除 label/family/parent 后编译结果与哈希不变。
2. 区域、接口、组件枚举置换后哈希不变。
3. 每个 gene 有消费者或被明确标为 inactive 且不参与搜索信用。
4. 缺失 required obligation 不得默认补齐。
5. alternatives/scenarios 量词正确。
6. 三种 Genome 任一版本不兼容时保持 `terminal_deferred`。
7. 编译器不产生任何物理 promotion。

