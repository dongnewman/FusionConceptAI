# AD-43 G1/G2 四轴 typed-absence 缺口审计

日期：2026-09-15  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
状态：`read_only_audit / review_pending`  
范围：AD-42 W0 完成后，复核 G1 `evidence_receipt_version` 与 G2
`applicability_profile_version`、`evidence_receipt_version` 的来源、类型域、
哈希依赖和可执行的最小 additive software-only V1 合同边界。

本审计只写本目录及其 `archive/**` raw/static sidecar；没有修改 core、
源码、测试、fixture、旧 receipt、AD-42 W0 产品、task manifest 或核心规划。
没有运行 Julia、DESC、provider、mesh、solver 或 physical workload，没有生成
candidate hash、declaration hash 或新的 declaration/payload。`present`、T0/T1/T2、
provider、mesh、solver、engineering、physical 和 R01–R10 全部保持 `false`。

## 决定

缺口是真实的合同缺口，不是 W0 checker 或 Python 环境造成的误报：

| 层 | W0 现状 | 当前 V1 源码事实 | 结论 |
|---|---|---|---|
| G1 evidence | `typed_absent` | 有 `G1DiffusionReceiptV1` 与 `g1_diffusion_receipt_v1`，但 receipt 类型没有独立的 receipt-version ref/字段，也没有 candidate/source-record/attestation 轴记录 | 可从该 receipt 合同定义一个 additive source-only V1 receipt-axis record；当前仍 `typed_absent` |
| G2 applicability | `typed_absent` | 有 `G2MBProfileV1`、`g2mb_profile_hash_v1` 和 `g2mb_profile_token_v1`，但没有显式 applicability-profile ref/version 记录 | 可从 G2MB V1 profile 定义一个 additive applicability record；不得把 G2 V5 `SpatialGrammarProfileV2` 冒充为该记录 |
| G2 evidence | `typed_absent` | 有 `G2MBReceiptV1` 与 `g2mb_receipt_v1`，但 receipt 类型没有独立的 receipt-version ref/字段，也没有 candidate/source-record/attestation 轴记录 | 可从该 receipt 合同定义一个 additive source-only V1 receipt-axis record；当前仍 `typed_absent` |

因此，三个缺轴可以合法由 additive software-only V1 contract records
补齐**合同定义层**，但不能凭本地 receipt 构造、profile hash、测试通过或
W0 的 `PresentPublicContractEnvelopeV1` 直接把当前 W0/W2R1 变为 present。
未来记录必须先证明来源字节和 canonical record schema，再由 W2R1 把它们
逐字段绑定到 fresh source payload、fresh seed、candidate/source record 和
独立 receipt。缺任一 candidate-bound 输入仍输出 `typed_absent` +
`terminal_deferred`；冲突、跨域 alias、历史复用或反向哈希依赖输出
`fail_closed`。

## 已核对的源码与合同

1. `src/Contracts/GenomeContractRegistry.jl` 的 `GenomeContractRef` 只有
   `uri`、`version`、`schema_hash`、`canonicalization_hash`、
   `compatibility_profile` 五字段；`src/IR/PhysicalTypes.jl` 的
   `QualifiedRefV1` 只有 `id`、`version`。二者不能靠 URI 或版本字符串互相
   解释。
2. `src/GenomeV5/G1/DiffusionDeclarationV1.jl:9-50` 定义 G1 V1 schema、
   canonicalization、applicability literal 和 profile hash。其
   `G1DiffusionReceiptV1`（约 `:467-500`）只包含 declaration/schema/
   canonicalization/profile hash、状态、gap、调用计数和 physical flag；
   `g1_diffusion_receipt_v1`（约 `:494-500`）从 declaration 生成该 receipt。
   源码没有 `evidence_receipt_version` 或 `applicability_profile_version`
   轴字段，也没有把 receipt version 作为独立 source record/attestation。
3. `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl:233-253` 的
   `G2MBProfileV1` 已有 profile id、3D/cartesian/tensor-product 和
   `contract_only` 语义；`:337-352` 计算 G2MB schema、canonicalization、
   profile hash/token。其 `G2MBReceiptV1`（约 `:554-590`）与
   `g2mb_receipt_v1` 只记录 declaration/source/schema/canonicalization/
   profile hash、admission/gap/error、调用计数和 physical flag。源码没有
   显式 applicability-profile ref/version 或 evidence-receipt-version 轴。
4. `src/GenomeV5/G1/GrammarProfileV2.jl`、`src/GenomeV5/G1/MechanismGenomeV5.jl`
   与 `src/GenomeV5/G2/SpatialGrammarProfileV2.jl`、
   `src/GenomeV5/G2/FieldGeometryGenomeV5.jl` 的四轴是 V5 Genome candidate
   identity 轴。它们必须作为负控保留，不能用来填 AD-42 W0 的 V1 declaration
   domain；V5 materializer 还会要求 candidate-bound V5 axes 和 downstream
   candidate hash。
5. AD-30 authority-source audit 已明确：G1 V1 没有 declaration/source
   receipt version，G2 V1 没有 applicability axis，且现有 receipt/mapping
   不是 readable candidate-bound authority。AD-37 的 publication contract
   明确要求四个轴逐层、同候选、带 source-record/identity/attestation；
   AD-39 要求 factory/declaration receipt 的可复查字节和 hash。AD-42 W0
   已把这一缺口按层写成 typed absence，并保留 `candidate_hash_created=false`
   与 `declaration_hash_created=false`。

W0 四个产品的当前 SHA-256 已在 manifest 和静态 raw receipt 中重新核对：
G1 envelope `8fbef1...44360`，G2 envelope `9a749c...a41b9`，fresh seed
recipe `e4662a...d8e74f`，materialization receipt
`2d969e...742a2f`。它们只证明软件合同物化；不证明 declaration authority。

## 合法的 additive 记录形态

可以新增记录类型或其等价的 versioned JSON contract，但不得扩展旧
`G1DiffusionReceiptV1`/`G2MBReceiptV1` 的语义、修改旧 canonical bytes、
改变 V5 axes，或把 receipt hash 直接当作 axis version。记录至少要有：

- `record_schema_version`、`layer`、`axis_kind`、`source_contract_type` 和
  `source_contract_schema_version`；
- source path、HEAD、exact bytes/SHA-256、source literal/profile descriptor
  hash，以及 record canonicalization/hash rule；
- `axis_ref`/`axis_version` 的独立来源和可重算规则；它不能由 payload hash、
  declaration hash、candidate hash、fixture URI 或历史 receipt 派生；
- `source_receipt_type` 或 `profile_type` 的 exact field order、typed fields、
  claim ceiling 和 zero-call boundary；
- candidate-bound 使用时的 `candidate_ref`、public contract ref、source-record
  hash、identity hash、attestation 和 fresh W2R1 receipt hash。上述任一项
  尚未有新鲜可读输入时，记录只能是 typed absence；不能填默认值。

G1 receipt record 必须引用 `G1DiffusionReceiptV1` 的 exact schema/field
   projection 和 `g1_diffusion_receipt_v1` 生成规则；它不得引用
   `GrammarProfileV2` 的 `evidence_receipt_version`。

G2 applicability record 必须引用 `G2MBProfileV1`、其 `profile_id`、profile
   hash/token 和 exact V1 profile source；它不得引用、复制或 alias
   `SpatialGrammarProfileV2` 的 V5 applicability axis。

G2 receipt record 必须引用 `G2MBReceiptV1` 的 exact schema/field projection
   和 `g2mb_receipt_v1` 规则，并保持 G2 source candidate 的
   `GenomeContractRef` 类型；不得把它转换成 G1 的 `QualifiedRefV1`。

## 最小有限工作单（仅提案，不在本审计中派发）

### AD43-AXIS-CONTRACT-RECORDS

Owner：Luna/high；G1/G2 source-domain author 可并行，different Luna/high
独立复核。该单只定义和 materialize source-only contract records；不创建
candidate declaration/payload，不创建 candidate hash，不开放 T0。它不新增
mainline task node，具体调度需由 Sol 在 AD-42 W2R1 派单时裁决。

精确产品文件（未来工作单的四个 product deliverables；本次不创建）：

1. `docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/evidence_receipt_axis_schema_v1.json`
2. `docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g1_evidence_receipt_contract_v1.json`
3. `docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_applicability_profile_contract_v1.json`
4. `docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_evidence_receipt_contract_v1.json`

Inputs：AD-42 W0 四个产品；`GenomeContractRef` 与 `QualifiedRefV1` 定义；
G1 `DiffusionDeclarationV1.jl`；G2 `MetricBoundaryDeclarationV1.jl`；G1/G2
V5 profile/Genome 源（仅作跨域负控）；AD-30 authority audit、AD-37 R2
publication contract、AD-39 repair-R1 input contract、AD-36 sidecar policy。
AD-40 W2 payload/receipt 只能作历史负控，禁止作为输入。future W2R1
candidate/source products 不属于本单的 source-only materialization 输入，
但 W2R1 必须消费本单结果并重新建立 candidate-bound axes。

Outputs：共享 evidence-receipt record schema；G1 receipt-axis contract record；
G2 applicability-profile contract record；G2 receipt-axis contract record。每个
记录必须含 source byte/hash closure、独立 axis ref/version、exact source type、
canonicalization rule、claim ceiling `software_contract_only`、缺失/冲突 union
和 no-runtime-call counters。记录的 `result` 只能属于：

`PresentAxisContractRecordV1 | AbsentAxisContractRecordV1 |
FailedAxisContractRecordV1`。

`PresentAxisContractRecordV1` 仅表示 source contract record 可由当前仓库
字节重算；它不是 `PresentBaselinePublicationV1`、不是 source-backed authority，
也不是 W0 declaration present。

依赖：AD-42 W0（`accepted_limited` preparation boundary）、UP1-01/02/03
contract requirements、AD-36 sidecar contract。它不依赖 AD-40 W2 products、
AD-37 present publication、T0 authority recheck、T1/T2、UP2、provider、mesh、
solver 或 physical execution。W2R1 对该单的合法边是单向的
`AD43-AXIS-CONTRACT-RECORDS -> AD42-W2R1-REAUTHOR-FRESH-PAYLOADS`；禁止反向
由 payload/declaration/candidate hash 产生 axis record。

退出门：

1. 每个 source/profile literal、schema、canonicalization、receipt/profile
   record 的 exact bytes/SHA-256 可复算；shared schema 不隐藏 layer-specific
   source type 或字段。
2. G1 receipt record 精确映射 `G1DiffusionReceiptV1`；G2 receipt record 精确
   映射 `G2MBReceiptV1`；G2 applicability record 精确映射 `G2MBProfileV1`。
3. V1/V5 domain、G1/G2 type、receipt hash/axis ref、source hash/declaration
   hash 均有 negative controls；fixture、synthetic、legacy、historical receipt、
   foreign layer、URI alias、missing profile/source 和 candidate-hash dependency
   均 fail-closed 或 typed-deferred。
4. 记录不生成 candidate/declaration hash，不调用 Julia/DESC/provider/mesh/
   solver/physical，不修改旧产品或 task manifest；direct JSON/hash/API/path/
   diff validation 具有 PID/UTC/exit/stdout/stderr/combined raw 证据；不同
   Luna 完成独立复核和 task-owned cleanup。

W2R1 仍须在自己的新 AD-42 目录生成 candidate-specific payload/receipts，
将本单四个 record 的 exact hashes 与 fresh seed/source-record/candidate binding
逐项绑定。若 W2R1 没有 fresh candidate/source/identity receipt，三处轴不能
从本单记录“自动 present”，仍返回 `AbsentDeclarationSourceV1` /
`terminal_deferred`。AD-37 publication、T0/T1/T2 和所有物理/工程门继续关闭。

## 结论边界

当前应保持：G1 evidence axis absent；G2 applicability axis absent；G2 evidence
axis absent；W0 software envelope 可重放但不是 declaration authority；W2R1
仍等待 additive axis contract records 与 fresh candidate/source inputs。这个
审计没有创造任何 record/product，只冻结了合法的最小后续 work-order 和 fail
closed 边界。父目标 R01–R10 不缩减。
