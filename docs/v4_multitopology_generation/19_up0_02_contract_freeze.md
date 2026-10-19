# B00/B04保留协议（UP0/UP1操作已完成）

本页保留当前仍需遵守的合同、F0–F5和N01–N10共50项覆盖；已完成的合同冻结/fixture编制操作不再派发。历史JSON原定义[up0_02_protocol](up0_02_protocol.json)只供规范与旧记录核对，不能覆盖当前实际状态。

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

历史protocol保存N01–N10每类5变体的原定义；当前UP1-04B真实50项primary+replay已在约定软件范围接受。下表仍是覆盖要求，不能用文档模板或局部子集替代正式消费者；实际记录见16已接受依赖索引。

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

N01–N10 的实际 validator 负控输出必须包含 mutation id、input hash、error code/path、solver/provider invocation count、archive diff 和 checker exit。既有合格B04记录只在原输入/行为/覆盖范围内复用；改变相关行为时按原正式覆盖回归。拒绝的 candidate 不是 `physical_fail`；validator 崩溃才归 `program_exception`。
