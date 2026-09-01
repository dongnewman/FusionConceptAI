# v4 共同合同、状态模型与 authority

## 1. 目的

本文是所有 v4 详细设计的共同依赖。它不定义三种 Genome 的内部字段，而是规定跨模块传递什么、谁有权修改什么，以及状态如何前向演化。

## 2. 规范性上游

v4 必须通过 `GenomeContractRegistryV4` 引用三种已经完成的 Genome 文档：

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
3. 同一 solver input 只真实执行一次；
4. 状态维度保持独立；
5. 所有中间 provider 缺口保持 `terminal_deferred`；
6. 所有 EvidenceEnvelope 可内容寻址且不可变；
7. 搜索模型输出不能进入物理证据字段；
8. 终局 disposition 只由最终 authority 产生。

