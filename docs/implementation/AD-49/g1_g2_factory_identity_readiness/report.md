# AD-49 G1/G2 factory、source identity 与 G2 mapping 就绪性审计

日期：2026-09-15  
状态：`readiness_audit_only`  
验收：`accepted=false`  
范围：只读核对 G1/G2 的真实 constructor/factory/export/registry、源定位、source identity、G2 显式映射和 W3-B 轴/同候选 join 的可派发边界。

本单没有实现 factory、没有生成 source declaration/content/declaration/final candidate hash，没有创建 identity、mapping、candidate-bound axis 或 join 产品；没有修改 `src/`、`test/`、fixture、registry、core、`task_manifest.json` 或任何既有 implementation 产品；没有运行 Julia、DESC、provider、mesh、solver、engineering、physics 或 search。唯一新增根产品是本目录的 `report.md`、`manifest.json`、`cleanup_inventory.md`；原始核验摘要只在 `archive/`。

## 观测基线与实际源码证据

仓库根为 `D:\006-Programing\LMC\FusionConceptAI`，观测 HEAD 为
`4b69f55f7f80240147a65a22809dc1207824dde2`。工作树有 334 条 status 行；既有脏文件、其他 agent 的收据和运行资料均保留。本单观察到 Python 进程，但没有 Julia/DESC/mesh/solver 进程；不触碰其他进程。

本次静态核验使用 `D:\Users\Newman\anaconda3\python.exe` / Python `3.13.5`，PID `87732`，UTC `2026-09-15T14:21:14.909155+00:00`–`2026-09-15T14:21:14.914362+00:00`，exit `0`。被核对的源码和测试字节如下：

| 路径 | bytes | SHA-256 | HEAD/工作树事实 |
|---|---:|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 31743 | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` | 当前文件存在，但 `git ls-files` exit 1，未进入 HEAD |
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | 30773 | `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61` | 当前文件存在，但 `git ls-files` exit 1，未进入 HEAD |
| `src/Contracts/GenomeContractRegistry.jl` | 2389 | `ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c` | tracked；仅定义五字段 `GenomeContractRef` |
| `src/IR/PhysicalTypes.jl` | 11801 | `dc51af9c34fe95dc74b579f6901bef56eb6d4da81b89281ae2734c3c3ad3a8d4` | `QualifiedRefV1` 仅有 `id`、`version` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 9655 | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` | 当前测试存在，未进入 HEAD |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | 11208 | `1647d7f72a4d1f2a8e9ff93543058ee6a7c9799d3988911d6b8ec7d8a65121db` | 当前测试存在，未进入 HEAD |

G1 的真实入口是 `G1DiffusionSourcePayloadV1`、`G1DiffusionDeclarationV1`、`g1_diffusion_declaration_v1` 和 `g1_diffusion_receipt_v1`。它校验 source payload、source hash、候选 `QualifiedRefV1`、可编辑字段和 operator closure，但没有独立 source locator、factory identity、source authority 或 trusted attestation 参数；`g1_diffusion_receipt_v1` 固定为 proposal/`terminal_deferred`，调用计数为零，不能作为 source-backed construction receipt。G1 顶层源码没有可消费独立 locator + AD-45 common handle + G1 public `GenomeContractRef` 的 factory。

G2 的真实入口是 `G2MBSourceV1`、`G2MBDeclarationV1`、`g2mb_source_v1`、`g2mb_declaration_v1` 和 `g2mb_receipt_v1`。G2 source 和 declaration 保持五字段 `GenomeContractRef`，source body hash 与 declaration hash 可由 typed values 重算；但源码没有独立 source locator、factory identity、trusted source identity 或 `GenomeContractRef -> QualifiedRefV1` mapping receipt。`g2mb_receipt_v1` 的 `provider_calls/mesh_calls/solver_calls/physical_evidence` 仍是软件合同计数与缺口状态，不能升级为 source authority。

`src/FusionConceptAI.jl` 当前没有 include 这两个 V1 declaration 文件；现有 G1/G2 contract tests 以 `Base.include(FusionConceptAI, ...)` 直接载入。未来 factory 必须采用 additive、显式 source module/test ownership；不得通过修改 `default_operator_registry()` 或旧 V5 registry 伪造 factory 可见性。

静态 API 搜索没有发现 G1/G2 source-authority factory、独立 locator、trusted source identity/attestation 或 G2 mapping API。`GenomeContractRef` 与 `QualifiedRefV1` 的 registry/type 域也没有 alias。当前唯一类似的 generic `SourceLocatorV1`/`FactoryConstructionReceiptV1` 仅在 parent baseline typed-absence scaffold；不能当作 G1/G2 factory authority。

## 上游收据边界

AD-42 W2R1 的四份冻结 authoring 产品和不同 Luna review 仍只有 source-authoring 软件范围：G1 payload `6180/f4841efa7e872a57e05c8eda687d951dd7775802ad3d07330947df72c5c97449`、receipt `13968/46d7329bd83188c280208b65ac58afc571c813c9d48e3732707dcf4d4bcb4210`；G2 payload `7086/7244861fa4c640035c06ac7b69623f048c17b86f9deeda71de8406c452bbcacf`、receipt `14337/7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c`。G1 authoring ref 为 `QualifiedRefV1`，G2 source ref 为 `GenomeContractRef`；两层 declaration/candidate identity hash 均不存在。

AD-43 四轴产品是 source-only contract；candidate/source-record/identity/attestation 字段仍为 `null`/`typed_absent`。AD-44 W3-A 的 G1/G2 repository-design records 已有 `pass_limited` 软件 provenance，但其 candidate binding 仍明确引用 AD-42 authoring namespace 或 typed source contract，不能成为 candidate-bound source authority；W3-B 八件产品尚未形成。AD-45 common `QualifiedRefV1/v5` handle 已由独立 review 以 `pass_limited` 接受，当前 handle 为 `fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7`，其身份角色严格是 `common_candidate_binding_handle_only`，`candidate_identity_created=false`，不能冒充最终 identity。

因此，当前缺口不是环境重装或测试缺口，而是四个真实合同门：独立 source locator、能消费 locator/handle/public contract 的 G1/G2 factory、trusted source identity/attestation、以及 G2 的显式 typed mapping。source/content/declaration hash 也必须在 factory 的真实输入闭合后生成；不能由本审计、W2R1 payload、AD-42 seed、URI、receipt hash、fixture 或 common handle 反推。

## 无环有限工作单

下列工作单均为后续建议，不能由本审计视为已派发或已实现。每单 owner 为 `gpt-5.6-luna/high`，由不同的 `gpt-5.6-luna/high` 独立复核；每单必须保存 direct JSON/hash/path/control、PID/UTC/exit/stdout/stderr/artifact hashes、失败历史和 task-owned cleanup。每单都不新增主线 machine node。

### AD49-S1：independent G1/G2 source locator freeze

状态：`proposed_ready_after_parent_review`；G1/G2 可并行。精确产品 4 件：

1. `docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_v1.json`
2. `docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_receipt.json`
3. `docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_v1.json`
4. `docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_receipt.json`

schema/result union 分别为 `G1IndependentSourceLocatorV1 | AbsentG1IndependentSourceLocatorV1 | FailedG1IndependentSourceLocatorV1`、`G2IndependentSourceLocatorV1 | AbsentG2IndependentSourceLocatorV1 | FailedG2IndependentSourceLocatorV1` 及各自 receipt union。输入是当前 G1/G2 source 文件、HEAD/path/`git ls-files` 状态、精确 bytes/SHA、AD-42 W2R1 source inputs 和 AD-44 records；输出只允许独立 locator/receipt。必须区分 tracked HEAD blob、untracked working-tree snapshot 与完整 source closure；当前 G1/G2 文件未 tracked，最初结果预期为 `Absent.../terminal_deferred`，不能把工作树快照当 source authority。根、路径、bytes、SHA、scope 或 HEAD 变化必须使旧 locator 失效。

依赖 AD-42 W2R1/AD-43/AD-44 只读输入；不依赖 T0/T1/T2。禁止生成 declaration/content/final candidate hash、factory receipt、mapping、identity、provider、mesh、solver、physics、search，禁止改 source/test/fixture/registry/core。退出门为独立记录可重算、状态闭合、negative controls 与不同 Luna review 齐全；cleanup 只清理本单 scratch。

### AD49-S2：G1/G2 factory identity and construction probe

状态：`blocked_on_S1`；G1/G2 可在各自 S1 后并行。精确产品 4 件：

1. `docs/implementation/AD-49/G1-FACTORY-PROBE/g1_factory_identity_probe_v1.json`
2. `docs/implementation/AD-49/G1-FACTORY-PROBE/g1_factory_construction_probe_receipt.json`
3. `docs/implementation/AD-49/G2-FACTORY-PROBE/g2_factory_identity_probe_v1.json`
4. `docs/implementation/AD-49/G2-FACTORY-PROBE/g2_factory_construction_probe_receipt.json`

schema/result union 为 `G1SourceFactoryIdentityV1 | AbsentG1SourceFactoryIdentityV1 | FailedG1SourceFactoryIdentityV1`、`G2SourceFactoryIdentityV1 | AbsentG2SourceFactoryIdentityV1 | FailedG2SourceFactoryIdentityV1` 及对应 construction receipt union。输入必须包括 S1 独立 locator、AD-45 common handle、对应 W0 public `GenomeContractRef`、实际 constructor signature、source payload/declaration typed input 和 registry snapshot。探针只能报告真实入口是否能消费这些输入、产生 candidate-bound source declaration/content hash 和可复放 construction receipt；不能以 V1 constructor 名称、fixture、测试 exit 或 generic scaffold 充当 factory。当前静态证据表明 G1/G2 均无这样的 factory，预期 probe 为 `Absent.../terminal_deferred`。

退出门要求记录 module path/bytes/SHA、函数/type、参数类型、source locator、common handle、public contract、registry untouched、semantic/source/declaration hash 的输入关系和 replay；缺入口是 typed absence，签名/路径/哈希冲突是 fail-closed。探针不创建 candidate identity/final package/T0，禁止 provider/mesh/solver/physics/search。

### AD49-F0：conditional minimal G1/G2 source-authority factories

状态：`conditional_blocked_until_S2_absent`；只有 S2 真实证明两层 factory 缺失后才可派发。精确源码/测试文件 4 件：

1. `src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl`
2. `test/GenomeV5/G1/g1_source_authority_factory_v1_tests.jl`
3. `src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl`
4. `test/GenomeV5/G2/g2_source_authority_factory_v1_tests.jl`

输入为 S1 locator、AD-45 common `QualifiedRefV1/v5` handle、G1/G2 各自 public `GenomeContractRef`、typed source payload、四轴 source-only contract 和真实 declaration constructor。输出是代码入口与 focused positive/negative tests；运行时结果联合必须是 `PresentG1/G2SourceDeclarationV1 | AbsentG1/G2SourceDeclarationV1 | FailedG1/G2SourceDeclarationV1`，construction receipt 同样保留三分支。G1 factory 必须显式保存 public contract 与 declaration 的绑定，即使 G1 declaration 内部 `candidate_ref` 仍是 `QualifiedRefV1`；G2 factory 必须保持 source/declaration 的 `GenomeContractRef` 类型。common handle 是同候选 binding handle，不是 identity。

Present 只允许在独立 locator、typed source、public contract、common handle、source/content/declaration hash 和 receipt 全部重算且可两进程 replay 时产生；无 source/authority 返回 typed absence，冲突或 foreign layer/ref 返回 fail-closed。代码必须 additive，不改 `default_operator_registry()`，不改旧 declaration schema，不从 payload/declaration/axis/final hash 反推 candidate identity，不创建 final candidate/package hash。不同 Luna 必须按文件 ownership 独立复核；失败 runner/raw 必须保留。

### AD49-S3：trusted G1/G2 source identity/attestation

状态：`blocked_on_S1_S2_and_independent_attestor`；两层可并行。精确产品 4 件：

1. `docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_v1.json`
2. `docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_receipt.json`
3. `docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_v1.json`
4. `docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_receipt.json`

result union 为 `G1/G2TrustedSourceIdentityV1 | AbsentG1/G2TrustedSourceIdentityV1 | FailedG1/G2TrustedSourceIdentityV1` 及对应 receipt union。输入为 S1 locator、S2/factory replay receipt、candidate-bound source declaration/content hash、AD-45 handle、对应 public contract、四轴 source contract 和不同 Luna 的独立 attestor identity。若没有真实可信签名/key 或完整 source closure，必须输出 `Absent.../terminal_deferred`；unsigned self-authored JSON 不是 trusted attestation。source bytes、semantic body、factory identity、attestor、handle 或 public ref 任一变化都必须触发新 identity input。

该单不生成 CandidateIdentityV1、final candidate hash、T0/T1/T2、provider/mesh/solver/engineering/physics/search 或 R01–R10；不同 Luna 既是实现审查者又需与实现者分离，cleanup 仅本单临时文件。

### AD49-G2-MAPPING：显式 GenomeContractRef → QualifiedRefV1 mapping

状态：`blocked_on_AD45_handle_S2_S3`；只允许 G2 source identity 输入闭合后派发。精确产品 2 件：

1. `docs/implementation/AD-49/G2-MAPPING/genome_contract_to_qualified_ref_mapping_v1.json`
2. `docs/implementation/AD-49/G2-MAPPING/mapping_receipt.json`

schema/result union 为 `GenomeContractToQualifiedRefMappingV1 | AbsentGenomeContractToQualifiedRefMappingV1 | FailedGenomeContractToQualifiedRefMappingV1` 及对应 receipt union。输入必须是实际 G2 五字段 `GenomeContractRef`、AD-45 common `QualifiedRefV1/v5`、G2 S1/S2/S3 source records、candidate-bound declaration/source hash、独立 mapping algorithm/profile ref。输出必须同时记录 source type=`GenomeContractRef`、target type=`QualifiedRefV1`、五字段 exact equality、common-handle equality、algorithm/profile hash、freshness、reviewer 和 replay receipt。

禁止 URI 后缀、version string、seed、payload/declaration/axis/final hash、fixture 或历史 receipt alias；不得把 G2 `GenomeContractRef` 变成 G1 的 `QualifiedRefV1`，也不得把 common handle改名为 G2 source identity。缺 source/attestation/mapping input 是 `Absent.../terminal_deferred`；任何 type/ref/hash/foreign-candidate 冲突是 `Failed.../fail_closed`。该单不能创建最终 candidate identity/hash 或打开 T0。

### AD49-W3B：candidate-bound axes and same-candidate join

状态：`blocked_on_S3_G2_MAPPING_and_fresh_identity_inputs`；G1/G2 axis attestations 可并行，join 必须串行汇聚。精确产品 9 件，路径逐项冻结如下：

- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/G1/payload_schema_attestation.json`
- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/G1/canonicalization_profile_attestation.json`
- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/G1/applicability_profile_attestation.json`
- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/G1/evidence_receipt_attestation.json`
- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/G2/payload_schema_attestation.json`
- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/G2/canonicalization_profile_attestation.json`
- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/G2/applicability_profile_attestation.json`
- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/G2/evidence_receipt_attestation.json`
- `docs/implementation/AD-49/W3-B-CANDIDATE-BOUND-AXES/same_candidate_join_receipt.json`

八件轴产品的 schema/result union 为 `CandidateBoundProvenanceAxisAttestationV1 | AbsentCandidateBoundProvenanceAxisAttestationV1 | FailedCandidateBoundProvenanceAxisAttestationV1`；join 为 `SameCandidateG1G2JoinV1 | AbsentSameCandidateG1G2JoinV1 | FailedSameCandidateG1G2JoinV1`。输入为 AD-44 W3-A 冻结 records/receipts、S1/S2/S3 两层 source identity、AD-45 fresh common handle、AD49 G2 mapping、W2R1 exact receipt hashes 和 source-only AD43 axis contract。八轴必须绑定同一 fresh common handle、各自 source record/hash/identity/attestor；G2 仍保持 `GenomeContractRef`，mapping 必须是单独 receipt。join 只能汇聚已独立通过的八轴和 mapping，不得从自身 hash 或未来 candidate hash建立身份。

缺任一轴、source identity、mapping、attestation 或同候选条件返回 typed absence/`terminal_deferred`；跨层 alias、foreign ref、重放、hash mismatch 返回 fail-closed。退出门为四轴 exact closure、same-candidate join 可独立复放、source mutation 使 join 失效、所有 no-publish/no-final-identity controls 完整及不同 Luna review。该单不得进入 AD-46 identity materialization、T0/T1/T2、UP2 或任何物理/工程执行。

## 结论与最早可派发项

当前结论固定为 `readiness_audit_only`、`accepted=false`。最早可在父审查后派发 AD49-S1 两层 independent locator；它很可能因 G1/G2 当前源码未进入 HEAD 而返回 typed absence，但这正是需要的真实证据。S1 后派发 S2 factory probe；只有 S2 对两层都产生独立 `Absent` 证据，才允许条件 F0 实现代码/测试。S3、G2-MAPPING 和 W3-B 必须按上述依赖推进，不能借 common handle、W2R1 payload、AD42 seed、AD43 source-only axes、AD44 repository record 或 G3 factory 替代。

本审计不缩减 R01–R10，也不授予 G1/G2 present、source authority、factory authority、mapping、candidate identity、T0/T1/T2、UP2、provider、mesh、solver、engineering、physical、search 或 L4 信用；L4 可信候选数继续为 `0`。
