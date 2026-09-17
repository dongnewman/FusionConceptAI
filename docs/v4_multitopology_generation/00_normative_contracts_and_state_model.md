# v4 共同合同、状态模型与 authority

**2026-09-17 执行规则更新：** 默认采用 [智能体自主研发合同](22_agent_local_execution.md)。项目责任由智能体承担；外部 CA、证明人、时间戳、ACK 或签发材料不再是主线前置条件。本文中的历史 external/trusted/authority 限制按该合同解释；保留实际输入、语义、数值与工程检查，不改写旧证据。

## 1. 目的

本文是所有 v4 详细设计的共同依赖，版本 `v4-upgrade-plan-20260914.1`。它定义跨层责任、版本、状态和证据边界；三层内部字段由对应 Genome 文档拥有。2026-09-14 用户已授权版本化补齐 Genome，替代旧版不修改 Genome 的范围限制；旧数据与历史证据语义保持只读。

本文中的合同图和新增数据包是设计规范，不表示同名 Julia 类型均已实现。现有类型以源码为准；拟议 API/schema 名称在 UP0-02 冻结后才能落地。不得因名称含 V4/V5/V2 就推断存在相应版本。

## 2. 规范性上游

v4 必须通过版本化 registry 引用三种 Genome 合同；当前已有类型化实现，但尚未具备本次目标要求的完整执行能力：

| 引用 | 所有者 | v4 可做 | v4 禁止做 |
|---|---|---|---|
| `mechanism_genome_contract_ref` | 机制 Genome 文档 | 校验、组合、规范化引用 | 重新解释状态、算子、守恒或机制语义 |
| `field_geometry_genome_contract_ref` | 场—几何 Genome 文档 | 校验、物化、编译求解输入 | 增加未声明场源、边界或基函数 |
| `realization_control_genome_contract_ref` | 实现—控制 Genome 文档 | 物化有限 alternatives/scenarios | 暗中增加组件、执行器、控制器或容量 |

每个引用至少包含 `uri`、`version`、`schema_hash`、`canonicalization_hash` 和 `compatibility_profile`。缺少或不匹配时只能 `terminal_deferred`，不得猜测兼容。

## 3. 核心数据包

### 3.1 CandidateStatePackageV4

```text
CandidateStatePackageV4
├── identity_ref                  # 展示身份，不参与路由和物理哈希
├── mission_contract_ref
├── mechanism_genome_ref
├── field_geometry_genome_ref
├── realization_control_genome_ref
├── canonical_hashes
│   ├── mechanism_hash
│   ├── field_geometry_hash
│   ├── realization_control_hash
│   ├── genome_bundle_hash
│   ├── physical_subject_hash
│   └── solver_input_hashes[]
├── lifecycle
├── applicability_records[]
├── compilation_records[]
├── proposal_lineage[]
├── stage_evidence_refs[]
├── archive_memberships[]
├── terminal_authority_ref | null
└── claim_ceiling
```

包内大对象采用内容寻址引用；不得在每一阶段复制完整 solver output。

### 3.2 ProposalEnvelopeV4

搜索模块的输出，只表达“建议下一步做什么”：

```text
proposal_id
candidate_or_prefix_ref
parent_refs[]
search_channel
typed_edit_trace[]
target_behavior_cell
predicted_outcomes
uncertainty
estimated_cost
model_or_rule_hash
requested_next_stage
```

`predicted_outcomes` 永远不是 evidence，也不得直接写入 candidate disposition。

### 3.3 EvidenceEnvelopeV4

```text
evidence_id
physical_subject_hash
scenario_hash
solver_input_hash
provider_manifest_hash
backend_revision
numerical_configuration_hash
applicability
match_status
resolution_status
stage_outcome
metrics_with_units
uncertainty_or_null
artifact_refs[]
independence_group
claim_ceiling
```

Evidence 必须不可变。重新运行产生新 envelope，不覆盖旧结果。

## 4. 独立状态维度

不得用一个 `status` 压缩所有含义。

### 4.1 Applicability

- `required`
- `not_applicable`，必须携带 proof/ref

### 4.2 Provider match

- `unique_match`
- `no_match`
- `ambiguous`
- `out_of_domain`
- `invalid_signature`

### 4.3 Resolution

- `resolved`
- `terminal_deferred`

### 4.4 Lifecycle

- `proposed`
- `compiled`
- `proof_pruned`
- `dormant`
- `materialized`
- `low_fidelity_evaluated`
- `frontier_admitted`
- `high_fidelity_pending`
- `integrated_executed`
- `terminal_classified`

### 4.5 Stage outcome

- `pass`
- `physical_fail`
- `numerical_fail`
- `unknown`
- `not_applicable`
- `terminal_deferred`

### 4.6 Terminal disposition

只有 `FinalWholeDeviceAuthorityV4` 可以发出：

- `credible_within_scope`
- `physical_fail`
- `numerical_fail`
- `unknown`
- `unsupported`

中间模块不得发出终局 `credible_within_scope` 或终局 `unsupported`。

## 5. Authority 分工

| Authority | 唯一职责 | 无权执行 |
|---|---|---|
| Genome owners | 定义三种 Genome 语义 | 依据搜索结果改写历史合同 |
| Candidate compiler | 规范化、类型/守恒/义务编译 | 给出物理可行性结论 |
| Proof authority | 验证永久剪枝证书 | 用代理或采样结果证明无解 |
| Search authority | 提议后代和预算 | 改写 evidence 或晋升信用 |
| Solver router | 按完整 capability signature 匹配 | 使用 family/name/ID 路由 |
| Stage frontier authority | 合并同层 evidence 并按预注册规则晋升 | 抢占未来层预算或反向补信用 |
| Pareto authority | 同 scope 内维护非支配集 | 跨证据层或硬门做万能评分 |
| Final whole-device authority | 终局整装分类和 claim ceiling | 推断缺失实验或工程证据 |

## 6. 哈希与等价

哈希必须分层：

- `mechanism_hash`：机制 Genome 的规范表示；
- `field_geometry_hash`：场—几何 Genome 的规范表示；
- `realization_control_hash`：实现—控制 Genome 的规范表示；
- `genome_bundle_hash`：前三者加 mission/bounds 的组合；
- `physical_subject_hash`：组合 Genome 经候选绑定物化后的确切物理对象；
- `solver_input_hash`：某 provider 的确切输入。

身份、名称、family、parent、benchmark flag、请求顺序和 shard 顺序不得进入物理哈希。节点、区域、接口、边界、线圈和 frontier 枚举置换必须在规范化后得到相同哈希。

## 7. 不可补偿门

以下顺序是强制的：

```text
合同合法性
→ 证明式剪枝审计
→ applicability/capability closure
→ candidate-bound numerical execution
→ stage hard gates
→ scoped Pareto
→ integrated whole-device execution
→ numerical VVUQ
→ validation VVUQ
→ terminal authority
```

新颖性、代理预测、信息增益、成本、复杂度和历史表现只能分配搜索预算；不能补偿任一必需硬门。

## 8. 兼容与迁移

v4 是 additive architecture：

- 历史 artifact、run 和 sealed acceptance 只读；
- v3/v141/v142 结果不因 v4 文档自动升级；
- legacy 状态进入 v4 时必须显式映射，无法无损映射则 `terminal_deferred`；
- 不允许把空 capability axis 解释为 wildcard；
- 不允许把缺失字段用装置家族默认值补齐。

## 9. 跨模块验收

任何 v4 实现合并前必须通过：

1. 三个 Genome 引用版本和哈希可解析；
2. 标签擦除后路由、哈希和判定不变；
3. 同一 campaign / execution attempt 的相同 solver input 去重；独立复放、新 backend 或预注册重复试验使用独立 execution identity，不得把缓存命中充当独立证据；
4. 状态维度保持独立；
5. 所有中间 provider 缺口保持 `terminal_deferred`；
6. 所有 EvidenceEnvelope 可内容寻址且不可变；
7. 搜索模型输出不能进入物理证据字段；
8. 终局 disposition 只由最终 authority 产生。

## 10. 本次升级的语义所有权与编译边界

| 层 | 唯一拥有的语义 | 跨层引用 |
|---|---|---|
| G1 | 状态、演化/约束方程、机制算子、闭合关系、适用假设、守恒账户和效应 | 引用 G2 的区域/场空间与 G3 的源、材料系数和端口，不复制各自定义 |
| G2 | 区域/接口/边界拓扑、连续几何、坐标/度量、场表示、空间离散与传递需求 | 守恒量含义来自 G1；外域源和硬件来自 G3 |
| G3 | 可实现源、资源网络、组件、材料属性模型、制造/热/结构约束、控制和故障场景 | 引用 G1 方程与守恒账户；组件占据 G2 几何域 |
| 执行层 | 方程编译、弱式/通量形式、离散装配、约束和数值耦合计划 | 不能凭 solver 模板添加未声明物理或删除必需义务 |

同一变量、能流或材料参数只能有一个语义所有者；所有投影、端口交换和反馈必须有方向、单位、时间/空间支撑和账本归属。模型的本构关系由 G1 表达，G3 拥有其材料数据和适用区间。G3 热/结构约束不是脱离 G1 方程的一份重复物理模型。

`typed Genome → equation IR → weak/flux residual IR → discrete system → coupled solver plan → candidate-bound evidence` 是目标编译链。ODE/DAE 不必人为构造空间弱式；FEM/FV/DG/谱方法各按经过验收的 lowering 路径执行，不能把全部数值方法强行伪装成同一种离散。

每次 lowering 输出应包括输入合同哈希、变量/端口映射、单位尺度、假设与闭合账本、支持域、边界/初值、残差及 Jacobian 支持、数值依赖和未满足义务。部分前缀可用于搜索；未闭合前缀不能进入需要完整物理输入的求解器。

## 11. 版本、规模与适用性

Genome schema、canonicalization、operator registry、closure library、geometry/discretization profile、material law、provider manifest 均须版本化并纳入相应内容哈希。当前硬编码基因/AST 上限是旧版可执行配置；新版用经过验证的有限 `GrammarProfile` 扩展组合规模。上限改变即新 campaign/profile，不能删限后把内存耗尽记物理失败。字段个数与网格自由度分别计费。

迁移必须提供旧/新版本、变换程序、语义保持说明或明确语义变化、往返/拒绝测试与身份失效范围。旧候选不能直接换标签升级；G1/G2/G3 物理内容改变需新身份、受影响的全链重算及新收据。UI 标签、请求顺序等无关信息仍不得影响物理身份。

能力声明必须覆盖模型、维度、几何/拓扑类、场空间、边界/接口、时间语义、材料与闭合、源和外部区域、导数/约束、离散方法及误差协议。有限适用域内自动组合才可称该域内通用；`no_match` 不能通过装置名称 fallback 变成支持。

复杂空间的场基还须审查拓扑完备性：在给定边界条件与势空间下，全局单值/周期势的 curl 表示可能遗漏允许的循环通量或调和自由度。必须显式记录相应循环/通量约束、调和基或等价 cut/多图册表示，不能把缺失的物理自由度当作规范冗余删去。重网格保留这些量；改变物理拓扑则重新建立表示和传递义务。参见 [18 的 FEEC 来源](18_sources_and_architecture_decisions.md)。

## 12. 执行事件、科学结果与 realization 闭环

在第 4 节独立维度之外，执行元数据至少区分 `completed`、`program_exception`、`human_interruption`、`not_executed`；记录原始退出码、异常和恢复 lineage。历史 `process_exception` 等别名保留原值并显式映射，不能重写旧 artifact。`scientific_fail` 是报告分组，必须继续细分 `numerical_fail` 与 `physical_fail`。

中间能力缺口为 match 原因加 `resolution=terminal_deferred`；`unsupported` 作为终局结论仍仅由最终 authority 发出。历史 provider 自带 `unsupported` 字段可保留为原生值，不得将其偷换成终局处置。非收敛解可做有标记的诊断，不能为下游工程或整装提供通过证据。

区分：物化是将已经声明的设计值变成确切对象；逆向 realization 是在 G3 合法设计空间内寻找能实现目标源/场的硬件；真实参考隐参反解是 R02 的识别与留出预测任务。这三者有不同目标和验收，不能彼此抵账。

逆向得到的场误差、供能损耗、热负荷和形变必须回代主物理，再联合检查耦合残差、守恒、约束及全周期账本。候选的设计 alternatives 使用存在性选择；同一设计必须满足全部 required operating/fault scenarios，不能每个场景重新选择硬件后合并为一个鲁棒装置。

## 13. 调度与验收的最小可执行包

[16 工作单](16_execution_work_orders.md) 与 [13 验收](13_acceptance_benchmarks_and_evidence.md) 联合定义交付。`accepted` 只在该工单范围内有效，不传播为父目标已完成。每个正式协议须在结果前冻结 `quantity / unit / normalization / threshold / grid-time sequence / algorithm-stop rules / scenario split / independence group / evidence ceiling`。后验调整只能创建新协议并保留旧运行。

重计算串行、文件独占、Luna 独立复核、Sol 架构裁决按 [14](14_agent_orchestration.md)。阶段顺序以 README 的 UP0–UP6 为准。01–09 的历史算法规模参数仅是建议，不授权跳过 UP1–UP4。
