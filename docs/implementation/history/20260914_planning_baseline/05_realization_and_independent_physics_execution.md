# v4 realization 编译与独立物理解算

## 1. 职责

本模块对应现有链路的“物理 realization 生成”，但其含义是：把三个既有 Genome 中已经声明的有限 alternatives、参数、基函数、组件和控制结构物化成确切、带单位、候选绑定的物理 subject 和 solver inputs。

它不得新定义 Genome，也不得因为 provider 方便而改变候选物理语义。

## 2. 输入

- `CompiledCandidatePrefixV4`，且 required nonterminal 已满足 completion policy；
- 三个 Genome 的规范对象和哈希；
- mission、bounds、operating/fault scenario；
- provider manifests；
- stage evidence request。

## 3. ExecutablePhysicalSubjectV4

```text
physical_subject_hash
genome_bundle_hash
mission_hash
design_alternative_id
operating_scenario_id
fault_scenario_id
regions / interfaces / boundaries
materialized_state_fields
materialized_sources_and_components
geometry_and_basis_coefficients
sensor_estimator_controller_graph
resource_and_conservation_ledgers
operator_obligations
coupling_contracts
finite_parameter_bounds
exact_units
required_evidence_stages
```

design alternatives 是存在量词；进入 scope 的 operating/fault scenarios 是全称量词。物化器必须完整记录两类量词，不能只保留表现最好的 scenario。

## 4. realization 规则

1. 每个 materialized value 可追溯到 Genome gene、mission 或显式 alternative。
2. 所有连续变量有有限上下界和规范单位。
3. 每个基系数有物理消费者、残差块或硬门。
4. 未消费 gene 不参与新颖性、优化或候选身份。
5. 参数、组件、边界、运行点或控制改变后更新 `physical_subject_hash`。
6. 任何影响 solver input 的变化都必须重新执行受影响阶段。
7. 物化失败不等于物理失败；无法满足 required declaration 时保持 deferred/unknown 并记录原因。

## 5. Provider capability matching

provider 的联合签名至少包含：

```text
kind
operator
complete physical-state set
source/target function spaces and dimensions
coordinates
boundary/interface relation
time semantics
required output and evidence level
input schema hash
backend revision
applicability bounds
```

匹配结果使用 [共同合同](00_normative_contracts_and_state_model.md) 的独立状态维度。空 axes 和 wildcard 非法。候选 ID、标签、family、parent、request index 和 hash 值本身不参与路由。

中间没有 provider、歧义或超域时写 `terminal_deferred`。只有最终整装 authority 在审查全部 closure 后可以给出终局 `unsupported`。

## 6. Solver-input compiler

对每个匹配 provider 生成：

```text
solver_input_hash
physical_subject_hash
provider_manifest_hash
coordinate/unit transforms
mesh/basis/time-step specification
boundary/interface data
initial/bound state
requested observables
tolerances and convergence criteria
artifact output contract
```

同一 `solver_input_hash` 在全 campaign 中最多真实执行一次。cache hit 必须返回原 evidence ref 和完整 provenance，不重新制造“独立”证据。

## 7. 多 provider 耦合

每条 `CouplingContractV4` 必须声明：

- 输入/输出 state hash；
- 坐标、单位、插值和投影；
- 时间同步与迭代顺序；
- 守恒误差预算；
- Jacobian/响应近似；
- 收敛与停止条件；
- provider independence group；
- 不一致时的状态规则。

一次性顺序后处理不能伪装成完整耦合。若 mission 要求 coupled closure，必须在同一 whole-device residual/iteration 中收敛。

## 8. 独立性原则

搜索器、代理模型和 Pareto 模块不得运行“内部评分求解器”并把结果直接当正式 evidence。正式 evidence executor：

- 只消费 frozen solver input；
- 不读取搜索排名；
- 不因候选来源调整阈值；
- 输出不可变 EvidenceEnvelope；
- 记录软件、环境、mesh、随机数和 backend hash；
- 对数值异常 fail-closed，但不把异常写成物理不利。

## 9. 已知装置 sentinel

sentinel 只用于：

- representability；
- reachability；
- executability；
- 声明作用域内的 regression。

sentinel 与未知候选走同一物化、路由、求解和审计链。公开 anchor 值不得注入 solver 输出，benchmark flag 不产生 promotion credit。

## 10. 输出

本模块向多保真 frontier 输出：

- `ExecutablePhysicalSubjectV4`；
- 一个或多个冻结 `EvidenceRequestV4`；
- provider closure map；
- solver-input hashes；
- deferred obligations；
- cost estimate，不包含物理通过预测。

## 11. 验收测试

1. 每个 materialized value 有上游追溯和单位。
2. 删除 label/family 后物化、路由和输入哈希不变。
3. 同一 solver input 只执行一次。
4. provider cache 不冒充独立代码证据。
5. design alternatives 和 scenarios 量词不混淆。
6. 松耦合结果不获得完整 coupled-closure 信用。
7. provider 缺口保持 terminal-deferred，且不会丢弃候选前缀。

