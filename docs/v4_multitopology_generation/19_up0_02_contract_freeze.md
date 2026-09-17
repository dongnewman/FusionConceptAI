# UP0-02 跨层合同与验收协议草案

状态：`accepted`，接受范围为 `accepted_scope=pre_result_contract_design`；本文件仍不能发出 `credible_within_scope` 或任何物理结果。执行边界为 `B00=false`、`B04=false`、`physical=false`。实际 schema 内容哈希、provider manifest 哈希、migration receipt 和运行结果必须由后续 UP1 实现与复核产生。

## 1. 范围和输入

本单承接 [00_normative_contracts_and_state_model.md](00_normative_contracts_and_state_model.md)、[10_genome_upgrade_execution.md](10_genome_upgrade_execution.md)、[11_physics_compilation_and_discretization.md](11_physics_compilation_and_discretization.md)、[12_composition_and_inverse_realization.md](12_composition_and_inverse_realization.md)、[13_acceptance_benchmarks_and_evidence.md](13_acceptance_benchmarks_and_evidence.md)、[14_agent_orchestration.md](14_agent_orchestration.md)、[16_execution_work_orders.md](16_execution_work_orders.md)、[17_luna_worker_prompt.md](17_luna_worker_prompt.md) 与已接受范围内的 [UP0-01 审计](../implementation/UP0-01/acceptance.md)。当前 HEAD 是 `4b69f55f7f80240147a65a22809dc1207824dde2`；live goal 是 `runs/goal_recovery_20260913_012528_cst/goal.json`，其 SHA-256 为 `96d38ae3504f3bc71ed89013d9c32a9eeb9fff45be9bd65fdd5a8821489eb9af`。

UP0-02 只冻结公共语义、输入输出、负例、最小 fixture 和验收门。它不实现源码、测试、provider、默认 registry 或共享入口；不改写 V1/V4 数据；不启动 Julia/DESC；不把文档存在或协议通过当作 R01–R10 完成。

## 2. 四个独立版本轴与公共引用

四个版本轴必须分别序列化并分别参与兼容判断：

| 轴 | 语义 | 改变时的规则 |
|---|---|---|
| `payload_schema_version` | 字段、类型、单位和所有权结构 | schema 不兼容时新 candidate identity；不能只改 profile 掩盖字段变化 |
| `canonicalization_profile_version` | key 顺序、数值/单位规范化、字节编码和 hash 输入 | canonical bytes/hash 变化必须显式记录；不能重解释旧 hash |
| `grammar_applicability_profile_version` | 可用算子、闭合、维度、拓扑、资源和 provider capability 范围 | 扩展只在 candidate-owned profile 中声明；不能扩张旧适用域 |
| `execution_evidence_receipt_version` | command、环境、独立性、退出、恢复和 evidence receipt 格式 | receipt 版本变化不等于 payload/schema 迁移；旧 receipt 只读 |

三层正式新类型命名如下：

- G1：`MechanismGenomePayloadV2` 是 payload；`MechanismGenomeV5` 是带版本轴、contract ref 和机制语义的外层 Genome。
- G2：`FieldGeometryGenomeV5` 包含区域、接口、外部域、坐标/度量、场、边界、拓扑和离散计划。
- G3 对外 bundle：`RealizationControlGenomeV5`；其内部必须包含 `RealizationGenomeV5`、`ControlGenomeV5`、`CoupledRealizationControlBindingV2`。

`CandidateStatePackage` 对外保留 G1、G2、G3 各一个独立 `GenomeContractRef`。G1/G2 ref 各自指向本层合同；G3 的 external bundle ref 必须可解析并在内部指向 `RealizationGenomeV5`、`ControlGenomeV5`、`CoupledRealizationControlBindingV2` 三个 child refs，同时携带四版本轴、`schema_hash`、`canonicalization_hash`、`profile_hash`（各自属于相应版本域）、`compatibility_profile` 和 candidate binding。当前草案将尚不存在的 hash 和 provider 值写为 `null` 并带 `pending_reason`；禁止填零值、旧值或猜测值。

V1/V4 payload bytes、hash、candidate identity、execution receipt 和 evidence 文件保持原字节和原语义，只读。G1 现有 `wire-domain:v2` 是既有 applicability/capability 标签，不等于 `MechanismGenomePayloadV2`，不能凭字符串相同或版本数字相近自动迁移。

新增 operator 只能注册在 candidate-owned additive registry，且必须绑定 operator version、语义/单位/效应、capability signature、适用域和 provider scope。UP0-02 和 UP1 不得修改 `default_operator_registry()`；缺 provider 时输出具体 gap 和 `resolution=terminal_deferred`。

内部 ECF 的 `unsupported` 只能被显式 compatibility mapping 转为中间 `provider_match` gap 或 `resolution=terminal_deferred`，并保留 source、target、reason、scope 和 mapping version。它不能成为最终 authority 的终态，也不能作为 wildcard provider；历史原生 `unsupported` 保持原值。

## 3. 结果前冻结字段

在任何正式结果、solver 输出或候选排名可见前，协议 manifest 必须冻结以下字段并写入其 canonical bytes：

`quantity`、`unit`、`normalization_scale`、rounding、解析/MMS oracle、threshold、grid/time sequence、basis/quadrature、solver algorithm、iteration/stop rules、resource/time budget、random seed、scenario split、calibration/validation/held-out IDs、provider registry/profile、environment lock、independence group、checker version、failure vocabulary、claim ceiling 和 evidence retention rule。

数值或物理门只能由冻结版本读取。看到结果后调整门、预算、seed、split、独立性或 claim ceiling 必须创建新的 protocol/campaign，保留旧 attempt 和 receipt，不覆盖旧证据。协议中未有实际 provider 或 schema hash 的字段必须为 `pending`/`null`，不能声称可执行能力已存在。

## 4. B00 F0–F5 可执行协议

B00 的范围是合同等价、身份、路由和证据边界。它不证明物理正确性。每个 fresh replay 必须生成新的 attempt receipt；同一 attempt 内相同 solver-input hash 最多执行一次，但不能用缓存伪装两个独立进程。

| 门 | 冻结输入 | 执行与精确预期 | 失败分类/claim ceiling |
|---|---|---|---|
| F0 输入登记 | 三层 payload、mission/bounds、四版本轴、完整 `GenomeContractRef`、环境锁、attempt id | 两份输入 manifest 的路径、字节、hash、版本和 scope 完整；缺字段、旧 ref 混入或未绑定 receipt 必须在 compile 前拒绝 | `invalid_type`/`invalid_closure` 或 `terminal_deferred`；不得进入 solver |
| F1 canonical package | F0 合同和固定 canonicalization profile | 两个独立进程各生成 canonical package；canonical bytes、package hash、三层 hash 和 bundle hash 逐字段相等。实际 hash 在实现时产生，当前不预填 | 生成差异为 `program_exception` 或 `numerical_fail`（按差异层）；`claim_ceiling=none`、`scope=contract_only` |
| F2 独立 replay | 相同 F0 输入、不同 process/attempt receipt、相同冻结环境 | 两进程均写 command、stdout/stderr、exit、environment、provider route 和 receipt；attempt receipt 必须不同，输入 hash 必须相同 | 中断为 `human_interruption`/`not_executed`；provider 缺口为 `terminal_deferred` |
| F3 标签擦除 | display、family、name、benchmark、节点/区域/接口排列变换样例 | 擦除或允许的排列只改变展示顺序；route、canonical hash、applicability、decision 和 claim ceiling 的逐字段 diff 必须为零 | 差异为 `program_exception`；不产生物理 evidence |
| F4 路由与兼容 | candidate-owned registry、provider signatures、ECF mapping | route 只由完整 contract/capability/profile 决定；ECF `unsupported` 只能落到显式中间 gap/`terminal_deferred`；不得命中 default wildcard | no match/out of domain/invalid signature 为 `terminal_deferred`；不能由中间层发 terminal authority |
| F5 证据闭合 | F0–F4 manifests、checker、独立性和 claim ceiling | canonical package、route、decision、receipt、attempt cache 和 evidence envelope 全部 candidate-bound；逐字段 diff=0；输出 B00 envelope 和 reproducible command set | artifact 缺失为 `unknown`/`not_executed`；B00 未闭合保持 `review_pending`，`claim_ceiling=none`、`scope=contract_only` |

B00 精确退出门：F0–F5 每门都有输入 hash、command、process exit、checker exit 和产物路径；同一输入的两个独立 canonical package/hash、标签擦除 route/hash/decision diff 均为零；没有中间模块发出最终 authority；任何一门缺失都不能把 B00 或父目标标为 accepted。

## 5. B04 十类负例

协议预注册每类五个 `illustrative_contract_mutations_pending_schema_binding` 变体（详见 JSON 的 `b04_frozen_mutation_templates`）；其中字段路径是说明性字段定位和参数标签，不是 JSON Pointer，也不是当前可运行的 mutation suite。预期 error 和 `expected_compile_provider_calls=0` 是待 schema 绑定后的目标，不是当前 B04 执行结果。UP1 schema/validator 实现后、首次运行前，正式 B04 必须另冻真实路径、参数、checker 和 receipt；不能把模板或文档状态记为通过。

| 编号 | 注入错误 | 精确预期 |
|---|---|---|
| N01 | rank/dimension 不匹配 | `invalid_type`，定位字段路径，solver/provider calls=0 |
| N02 | 单位或归一化不一致 | `invalid_type`，报告 expected/actual unit 或 scale，calls=0 |
| N03 | 时间语义/离散类型不匹配 | `invalid_type`，报告 continuous/discrete mismatch，calls=0 |
| N04 | 同一 conservation/energy account 重复 owner（含 double-count energy） | `invalid_closure`，报告重复 owner 和计能项，calls=0 |
| N05 | interface flux/traction/current 未成对 | `invalid_closure`，报告 interface 与方向，calls=0 |
| N06 | source/source-to-field binding 缺失，或 G3 return path/heat sink 缺失 | `invalid_closure`，报告缺失 binding/return/heat-sink，calls=0 |
| N07 | boundary 非闭合、越界或外部项未声明 | `invalid_boundary`，报告 region/boundary path，calls=0 |
| N08 | geometry/chart/mesh 参数越界或拓扑非法 | `invalid_boundary` 或 `invalid_closure`，报告具体节点，calls=0 |
| N09 | 空 capability axis、缺 provider 或 signature 不匹配 | `provider_match=no_match|invalid_signature`，`resolution=terminal_deferred`，不进入 solver |
| N10 | foreign/stale receipt、schema/profile/hash 不匹配 | `invalid_type` 或 `terminal_deferred`，报告 receipt/source/target mismatch，不能复用 evidence |

N01–N10 的 future validator 负控输出必须包含 mutation id、input hash、error code/path、solver/provider invocation count、archive diff 和 checker exit。当前没有 validator execution、calls=0 运行证据或 B04 acceptance；UP1-04 不得凭这些 illustrative templates 接受 B04。拒绝的 candidate 不是 `physical_fail`；validator 崩溃才归 `program_exception`。

## 6. UP1 三层最小 fixture（仅协议，不实施）

fixture id 固定为 `UP1-FX-001`，用途是证明三层合同可解析、可绑定、可生成确定性 plan；它不宣称真实物理 provider、收敛或装置能力。

```json
{
  "fixture_id": "UP1-FX-001",
  "mission": {"name": "contract_smoke", "quantity": "scalar_field", "unit": "1", "coordinate_unit": "m"},
  "version_axes": {
    "payload_schema_version": {"g1": "V2", "g2": "V5", "g3": "V5"},
    "canonicalization_profile_version": "pending",
    "grammar_applicability_profile_version": "pending",
    "execution_evidence_receipt_version": "pending"
  },
  "candidate_state_package": {
    "g1_ref": {"uri": "pending://GenomeV5/G1", "version": "MechanismGenomeV5", "payload_type": "MechanismGenomePayloadV2", "schema_hash": null, "schema_hash_pending_reason": "UP1 G1 schema not yet implemented", "canonicalization_hash": null, "canonicalization_hash_pending_reason": "canonicalizer not yet implemented", "compatibility_profile": null, "compatibility_profile_pending_reason": "G1 applicability profile pending"},
    "g2_ref": {"uri": "pending://GenomeV5/G2", "version": "FieldGeometryGenomeV5", "schema_hash": null, "schema_hash_pending_reason": "UP1 G2 schema not yet implemented", "canonicalization_hash": null, "canonicalization_hash_pending_reason": "canonicalizer not yet implemented", "compatibility_profile": null, "compatibility_profile_pending_reason": "G2 applicability profile pending"},
    "g3_ref": {"uri": "pending://GenomeV5/G3", "version": "RealizationControlGenomeV5", "schema_hash": null, "schema_hash_pending_reason": "UP1 G3 schema not yet implemented", "canonicalization_hash": null, "canonicalization_hash_pending_reason": "canonicalizer not yet implemented", "compatibility_profile": null, "compatibility_profile_pending_reason": "G3 applicability profile pending", "children": {
      "realization_ref": {"uri": "pending://GenomeV5/G3/realization", "version": "RealizationGenomeV5", "schema_hash": null, "schema_hash_pending_reason": "UP1 G3 schema not yet implemented", "canonicalization_hash": null, "canonicalization_hash_pending_reason": "canonicalizer not yet implemented", "compatibility_profile": null, "compatibility_profile_pending_reason": "realization profile pending"},
      "control_ref": {"uri": "pending://GenomeV5/G3/control", "version": "ControlGenomeV5", "schema_hash": null, "schema_hash_pending_reason": "UP1 G3 schema not yet implemented", "canonicalization_hash": null, "canonicalization_hash_pending_reason": "canonicalizer not yet implemented", "compatibility_profile": null, "compatibility_profile_pending_reason": "control profile pending"},
      "binding_ref": {"uri": "pending://GenomeV5/G3/binding", "version": "CoupledRealizationControlBindingV2", "schema_hash": null, "schema_hash_pending_reason": "UP1 G3 schema not yet implemented", "canonicalization_hash": null, "canonicalization_hash_pending_reason": "canonicalizer not yet implemented", "compatibility_profile": null, "compatibility_profile_pending_reason": "binding profile pending"}
    }}
  },
  "g1": {
    "state": "u",
    "coordinates": ["x", "y", "z"],
    "domain": "[0,2] x [0,1] x [0,1]",
    "manufactured_field": "u(x,y,z)=1+x",
    "equation": "-div(grad(u)) = 0",
    "boundary": {"x=0": "u=1", "x=2": "u=3", "y=0": "du/dy=0", "y=1": "du/dy=0", "z=0": "du/dz=0", "z=1": "du/dz=0"},
    "state_type": "scalar_field",
    "state_unit": "1",
    "conservation_account": {"id": "scalar_flux", "unit": "1/m", "owner": "G1"},
    "operator_registry": "candidate-owned-additive-only"
  },
  "g2": {
    "regions": ["Omega_left=[0,1] x [0,1] x [0,1]", "Omega_right=[1,2] x [0,1] x [0,1]"],
    "interface": {"location": "x=1", "normal": "+x", "unit": "m", "condition": "u_left=u_right; flux_left=flux_right", "account_owner": "G1.scalar_flux"},
    "mesh": {"cells_per_region": [2,2,2], "basis": "linear", "quadrature": "declared_pending"},
    "legal_alternative": {"regions": ["[0,2] x [0,0.5] x [0,1]", "[0,2] x [0.5,1] x [0,1]"], "interface": "y=0.5, normal=+y, same trace/flux continuity"},
    "illegal_interface": {"left_face": "x=1", "right_face": "x=1.1", "expected": "invalid_boundary|invalid_closure"},
    "external_domain": "none_declared_for_fixture"
  },
  "g3": {
    "realization": {"source_basis": "scalar_boundary_driver", "capacity": "declared_pending"},
    "control": {"sensor": "u_boundary", "actuator": "boundary_driver", "fault": "open_circuit"},
    "signal_ports": [
      {"id": "source_signal", "type": "scalar_boundary_driver_signal", "unit": "1", "direction": "out", "account_ref": "G3.field_boundary_signal"},
      {"id": "sensor", "type": "boundary_scalar_sensor", "unit": "1", "direction": "in", "account_ref": "G3.field_boundary_signal"},
      {"id": "actuator", "type": "boundary_driver_actuator", "unit": "1", "direction": "out", "account_ref": "G3.field_boundary_signal"},
      {"id": "fault", "type": "open_circuit_fault", "unit": "1", "direction": "in", "account_ref": "G3.fault_state"}
    ],
    "resource_ports": [
      {"id": "source_effort", "type": "electrical_effort", "unit": "V", "direction": "out", "account_ref": "G3.source_power"},
      {"id": "source_flow", "type": "electrical_flow", "unit": "A", "direction": "out", "account_ref": "G3.source_power"},
      {"id": "load", "type": "power_load", "unit": "W", "direction": "in", "account_ref": "G3.load_power"},
      {"id": "return", "type": "return_flow", "unit": "A", "direction": "in", "account_ref": "G3.return_power"},
      {"id": "heat_sink", "type": "thermal_sink", "unit": "W", "direction": "out", "account_ref": "G3.heat_rejection"}
    ],
    "accounts": [
      {"id": "field_boundary_signal", "unit": "1", "owner": "G3.signal_ledger"},
      {"id": "source_power", "unit": "W", "owner": "G3.energy_ledger"},
      {"id": "load_power", "unit": "W", "owner": "G3.energy_ledger"},
      {"id": "return_power", "unit": "W", "owner": "G3.energy_ledger"},
      {"id": "heat_rejection", "unit": "W", "owner": "G3.thermal_ledger"},
      {"id": "fault_state", "unit": "1", "owner": "G3.fault_ledger"}
    ],
    "resource_binding": "source_effort*source_flow -> source_power; load -> load_power; return_flow -> return_power; heat_sink -> heat_rejection; ports reference accounts and never own them",
    "binding": "source_signal/actuator -> g1.boundary; load -> g1.field; return -> source ledger; heat_sink -> thermal ledger; account owners require UP1-03 validation; g2.interface_ownership_preserved"
  },
  "expected_execution": {"structural_admission": "after_schema_available", "owner_uniqueness": "pending_validation", "physical_solver": "not_executed", "claim_ceiling": "none", "scope": "contract_only"}
}
```

执行步骤和预期如下：

1. 用固定 JSON key 顺序、UTF-8/LF 和协议指定 canonicalizer 读取 fixture；输出三层 ref、字段路径和完整 ownership map。缺少任何 schema hash 时保留 `pending`，不得用旧 hash 填充。
2. 待 schema 可用后执行 G1/G2/G3 admission 与 cross-layer binding。当前预期 `structural_admission=after_schema_available`、`owner_uniqueness=pending_validation`；G1 方程、G2 区域/接口、G3 signal/resource ports 与 ledger account 的类型/单位/引用需由 UP1-03 校验；不存在 provider 时 `provider_match=no_match`、`resolution=terminal_deferred`。
3. 生成确定性的 `GenomePlan`、equation/field/realization-control binding 摘要和 candidate-bound input manifest。预期字段路径、单位、接口方向、两区域网格计数和 fault 名称逐次一致；实际 plan hash 由实现产生并写入 receipt。
4. 预注册 N01–N10 的 template；UP0-02 不运行负控。待 UP1 validator 可用后，逐个模板在 compile/provider 前拒绝、solver/provider invocation=0，且不产生 physical evidence。
5. 在未来 UP1/UP2 运行门中以两个独立进程执行 F1–F5；预期 canonical package/hash、route、applicability、decision diff=0，attempt receipt 不同，`claim_ceiling=none` 且 `scope=contract_only`。本 fixture 通过不提供 B01/B02/B03/B05/B06/B07/B08/B09/B10/B11/B12/B13 的物理或最终 evidence credit。

## 7. B01–B13 未冻结字段与触发条件

本单只列出待冻结项，不把 13 文档中的 `suggested_initial_protocol` 当成正式门。每项在指定触发条件满足后，由 Sol/集成者写入新的版本化 acceptance protocol；结果可见后不得回填。

| benchmark | 当前 pending 字段 | 冻结触发条件 |
|---|---|---|
| B01 | MMS family、单位/scale、三层 grid、两实现、residual/error/order 门、stop rule、checker | UP2-01/02 提交解析 oracle、网格/quad manifest、两独立实现和资源预算 |
| B02 | nested levels、account 定义、scaled defect、`p_declared` 区间、time step 与 estimator | UP2-02/03 提交守恒 ledger、三层网格和独立 order/Richardson 计算 |
| B03 | calibration/validation/held-out IDs、先验、噪声/缺测、RMSE、coverage、初值规则 | UP4-03 提交真实来源、数据 hash、split manifest 和可识别性计划 |
| B04 | mutation 具体 payload、每类样本数、稳定 error path、archive/checker schema | UP1-01/02/03 提交三层 validator schema 和负控 fixture |
| B05 | topology pair、scenario 数、接口 account/scale、independent providers | UP2-03 提交两个适用 topology、provider signatures 和 transfer ledger |
| B06a | 外域半径、mesh levels、BC variants、敏感性/误差预算 | 使用外域 provider 且 UP2-03 完成 domain manifest |
| B06b | full/truncated basis、tail bound 形式、field error scale、采样域 | G2 basis evaluator 与独立 tail checker 可执行 |
| B06c | ROM train/validation/OOD/held-out split、detector、fallback、高保真 provider | 明确选择 ROM 路线并锁定 basis/hash、OOD 与 fallback provider |
| B07A | source hardware basis、制造/供能边界、inverse 参数、初值/多起点/误差门 | UP4-01 有 candidate-bound source provider、材料和制造数据 |
| B07B | reference provenance、隐藏参数、observation noise/mask、held-out、coverage | UP4-03 取得真实参考数据及独立留出记录 |
| B08 | full engineering scenarios、power/thermal/structural/control/fault margins、closure | UP4-02/04 提交每项 provider、ledger、故障矩阵和 checker |
| B09 | rewrite conditions、unit/conservation proofs、saturation/stop/budget、equivalence scope | UP5-01 提交 checker hash、ruleset、饱和和不完整状态记录 |
| B10 | baseline/capability increment、campaign size、seed、effect/margin、multiple testing | UP5-02/03 完成配对 baseline、failure frontier 和预注册统计门 |
| B11 | environment lock、fresh replay count、independence groups、artifact completeness、recovery recipe | 集成者提交可复放包、独立 checker 和恢复 receipt |
| B12 | system boundary、cycle、required scenarios、uncertainty/model discrepancy、confidence/lower bound | UP6-02 提交 immutable energy ledger、分布/不确定性和独立重算 |
| B13 | descriptor scope、外部来源、查询式/日期/覆盖、独立审查人数和等价规则 | UP6-03 提交 external prior-art corpus、查询日志和独立审查报告 |

## 8. UP1 三并行写入路径建议

三个实施者可以并行，但必须写入互斥路径，均以前述协议为输入，且不能改公共入口：

| worker | 唯一建议路径 | 输入/输出/退出门 |
|---|---|---|
| UP1-01 G1 | `src/GenomeV5/G1/`、`test/GenomeV5/G1/`、对应独立 fixture/manifest | 输入 G1 新合同与 B00/B04；输出 G1 admission、operator semantic/units/effect、closure diagnosis 和负例；退出门为合法/非法输入可确定分类，未完成 provider 为 `terminal_deferred` |
| UP1-02 G2 | `src/GenomeV5/G2/`、`test/GenomeV5/G2/`、对应独立 fixture/manifest | 输入 G2 新合同与 B04/B05/B06；输出 region/interface/chart/mesh plan、方向和拓扑负例；退出门为结构计划确定、越界拒绝、无 provider 不越权 |
| UP1-03 G3 | `src/GenomeV5/G3/`、`test/GenomeV5/G3/`、对应独立 fixture/manifest | 输入 G3 bundle 与 B04/B08；输出 realization/control/fault/resource binding；退出门为 owner/容量/故障路径确定，未有工程 provider 不发物理 claim |

以上是 UP0-02 接受后派发的写入建议，UP0-02 不实施它们。UP1-01/02/03 可按互斥路径进入实现，UP1-04 集成者拥有唯一公共 registry/package entry、migration receipt 和受影响 identity 重建；三 worker 不得互相写目录，也不得修改 `default_operator_registry()`、旧 tests 或旧 runs。

## 9. 退出门、阻塞和独立复核

UP0-02 当前交付的是 B00 F0–F5、B04 十类负例和 UP1 fixture 的预注册协议；它不要求现在执行 B00、生成 schema/provider hash 或产生 fixture receipt。该交付已接受，但仅限 `pre_result_contract_design`；B00/B04 执行、实际 schema/provider hash、receipt 和物理结果仍待后续工单。

阻塞完整退出门的具体输入是：三层实际 schema/profile 内容及 hash、canonicalizer、migration program/receipt、candidate-owned registry、G1/G2/G3 provider signatures、单位/闭合/离散实现、B01–B13 触发条件对应的数据和 checker、锁定环境与命令、独立复核报告。缺口应分类为 `unknown` 或 `resolution=terminal_deferred`，不能伪造 `unsupported` 或物理失败。

独立复核者 `up0_independent Luna(high)` 已通过对 18 的 AD-09–AD-16、JSON 可解析性、F0–F5 的输入/输出/失败分类、N01–N10 的 compile-before-provider 门、fixture 的无 hash/provider 占位纪律、B01–B13 pending/trigger 一致性、UP1 路径互斥和旧 dirty 保护的核对。Sol 接受本单的预结果合同设计范围；R01–R10 和 live goal 状态不变。
