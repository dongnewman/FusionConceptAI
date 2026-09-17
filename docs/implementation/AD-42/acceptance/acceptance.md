# AD-42 public contract materialization cycle audit — 架构验收裁决

日期：2026-09-15  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
状态：`accepted_limited`  
实现状态：`not_dispatched`  
验收范围：`architecture_only_cycle_break_and_finite_W0_to_W2R1_boundary`

## 裁决

依据 AD-42 原始审计、其冻结输入闭合以及不同 Luna 的
`independent_review_r1=pass_limited`，接受 AD-42 的无内在 cycle 架构判断和
W0 → W2R1 两个有限 work-order contract。合法方向是：精确的 G1/G2 V1
schema/profile material → fresh seed namespace → W0 public contract envelope →
W2R1 source payload authoring → 后续 declaration/candidate identity。任何由
payload、declaration 或 final candidate hash 反向产生 public URI、public ref 或
seed 的边必须 `fail_closed`。

W0 已依据不同 Luna 的 `independent_review_r1=pass_limited`，接受为
`accepted_limited`，范围严格为 `software_contract_materialization_only`。
W0 不生成最终 candidate hash、declaration authority、binding、T0/T1/T2 或
物理结果；W2R1 仍须等待 AD-43 axis records，并且不执行 publication、UP2、
provider、mesh、solver 或物理工作。并行的 AD-40 W2 四个产品只作为冻结的历史
负控，point-in-time excluded，不得回填 W0/W2R1。

另一个并行任务已经在 AD-42/W0-PUBLIC-CONTRACT-ENVELOPE 生成了 W0 四个产品。
它们的本地软件合同物化现已纳入 `accepted_limited` 状态同步；这不把
`PresentPublicContractEnvelopeV1` 提升为 source-backed declaration authority、
candidate identity、T0/T1/T2 或任何 R credit。W2R1 四个未来产品仍未生成。

## 类型与域边界

G1 V1 继续使用 `DiffusionDeclarationV1` 的实际 schema/profile 域，并保留
`QualifiedRefV1` candidate 类型。G2 继续使用 `MetricBoundaryDeclarationV1` /
`G2MBSourceV1` 域，并保留 `GenomeContractRef` source candidate 类型。G1 V5
`GrammarProfileV2`/materializer 与 G2 V5 `FieldGeometryGenomeV5` 只作为独立的
负控；它们不能冒充 W0/W2R1 的 V1 public contract，也不得与 V1 declaration
或 G2MB V1 进行 cross-domain 合并。

## 当前 claim ceiling

本裁决只接受架构和有限工作单边界，`claim_ceiling=architecture_only`。
当前 `present`、`T0`、`T1`、`T2`、provider、mesh、solver、engineering、
physical 和 `R01–R10` 全部保持 `false`。没有执行 Julia、DESC、provider、mesh、
solver 或物理 workload；文档、JSON/hash/path 检查、测试或 agent 退出码不能替代
物理与工程证据。

## 两个有限 work-order

`AD42-W0-PUBLIC-CONTRACT-ENVELOPE` 的四个精确产品是 G1 envelope、G2 envelope、
fresh seed binding recipe 和 materialization receipt。其结果联合为
`PresentPublicContractEnvelopeV1 | AbsentPublicContractEnvelopeV1 |
FailedPublicContractEnvelopeV1`；缺少真实 V1 source/profile/axis/seed 必须走
typed absence/`terminal_deferred`，域矛盾、历史/fixture/synthetic 复用或反向 hash
依赖必须 `fail_closed`。

`AD42-W2R1-REAUTHOR-FRESH-PAYLOADS` 依赖 W0，保留每层两件产品的形状，写入
AD-42 的新目录且不覆盖 AD-40 W2；其结果联合为
`CanonicalDeclarationSourceV1 | AbsentDeclarationSourceV1 |
FailedDeclarationSourceV1`。W0 ref 必须逐字段相等，两个层必须共用 fresh seed
recipe，且不得生成 candidate hash。完整输入、输出、禁止边、退出门和路径在
[AD-42 原始 manifest](../public_contract_materialization_cycle_audit/manifest.json)
中冻结。

## 证据与清理

验收记录了 14 个冻结输入、4 个历史 AD-40 W2 产品、11 个 AD-42 审计 sidecar、
AD-42 独立复核 report/manifest/raw hashes，以及真实 JSON/hash/path/control 和
计划 DAG 验证的 PID、UTC、exit code 与 raw streams。验收 manifest 自身
`self_hash_excluded=true`；其余产品和 raw sidecar 均以字节数与 SHA-256 闭合。

W0 四个产品的路径、字节数和 SHA-256 另列为本地软件物化的 accepted-limited
产品；它们不改变本裁决的 architecture-only claim ceiling，也不计入旧审计的
14/4/11 冻结统计。本次状态同步记录独立复核 40/40、直接 validation 21 checks
和 fresh status validator 15/15，并保留所有历史失败收据。

清理仅限本任务自有临时文件；历史失败收据、原始审计、独立复核和其它 agent 的
dirty work 保留。没有修改 core、task manifest、AD-42 原审计、AD-40 W2 产品、
源码或测试。
