# AD-42 public contract materialization and authoring-cycle audit

日期：2026-09-15  
观测 HEAD：4b69f55f7f80240147a65a22809dc1207824dde2  
状态：read_only_audit / accepted=false  
范围：AD-40 W2 的 G1/G2 四个现有产品与其证据 sidecar、public contract materialization、source payload 与 candidate binding 的字段和哈希依赖。

本审计只写本目录，不修改 core、源码、测试、task manifest、旧收据或 AD-40 W2 四个产品。没有运行 Julia、DESC、provider、mesh、solver 或物理程序，没有生成 candidate hash，也没有把 typed absence 改成 present。所有 present、T0/T1/T2、provider、mesh、solver、engineering、physical 和 R01–R10 结论保持 false。

## 结论

AD-40 W2 当前变成 AbsentDeclarationSourceV1 的直接原因是真实的：它要求一个 fresh、nonfixture 的 public GenomeContractRef，但当前 checkout 没有 candidate-bound public contract record 或可复查的 materialization envelope。现有四个 W2 产品中，G1/G2 payload 与 authoring receipt 都把 public_genome_contract_ref 记录为 typed absence；这不是测试或 runner 退出码造成的假缺口。

审计发现一个需要拆开的语义问题。GenomeContractRef 本身只有五个字段：uri、version、schema_hash、canonicalization_hash、compatibility_profile；它没有 candidate_hash 或 QualifiedRefV1 字段。因而 public contract 可以在 candidate identity 之前由冻结的 schema、canonicalization 和 profile materialization 产生。candidate-specific QualifiedRefV1、authoring seed commitment、source payload、declaration hash 和最终 Genome candidate hash 应在后续 binding/identity 层产生。若把 public contract URI 直接定义为 H(payload) 或最终 candidate hash 的别名，才会形成非法循环。

因此，W2 可以通过一个最小 additive 的 W0 public-contract-envelope 先行解除缺 public ref 的输入缺口，再用 W2R1 重新生成 G1/G2 payload authoring 四产品。该结论有两个硬限定：

1. W0 只能冻结 public contract envelope 和同一次 fresh authoring seed 的 typed candidate namespace/binding recipe，不能生成最终 candidate hash、declaration receipt、present record 或 T0 authority。
2. G1 和 G2 必须使用各自实际 V1 declaration schema/profile 的 hash domain。G1 QualifiedRefV1 candidate 与 G2 source 内部的 GenomeContractRef 继续是不同类型；G2 V5 FieldGeometryGenomeV5 的外层 contract 不能冒充 G2 metric-boundary V1 public contract。若实现者不能从已接受的 V1 source/profile bytes 重建这两个 envelope，W0/W2R1 只能返回 typed absence/terminal_deferred，不得制造 ref。

## 已核对的现状

AD-40 W2 当前四个产品为：

- docs/implementation/AD-40/RSDA-G1-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json
- docs/implementation/AD-40/RSDA-G1-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json
- docs/implementation/AD-40/RSDA-G2-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json
- docs/implementation/AD-40/RSDA-G2-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json

四个产品共享 authoring seed commitment 5cbfb8f31486d52ef5f0f5e3dcc3f215394d0f5562a3061f13cb9edc2892acb0，但该轮显式 candidate_identity.created=false、hash=null，并且 G1/G2 public ref 都是 typed absence。该轮只能作为失败/缺口历史，不能作为 W0 的 source、seed 或 public ref 输入；W0/W2R1 必须接收一个新的、由调度器冻结的 seed，并显式拒绝复用该旧 seed、旧 payload、fixture URI、synthetic URI 或历史 receipt。

AD-37 的 present publication contract 需要：G1 fresh QualifiedRefV1 candidate 加 exact GenomeContractRef public contract；G2 common QualifiedRefV1 candidate 加 exact source GenomeContractRef 以及五字段 G2 mapping receipt。缺任一 authority、axis、source/factory receipt 或 identity review 都只能走 typed absent/terminal_deferred；冲突走 fail_closed；意外异常走 program_exception。

## 字段与哈希依赖

### G1 V1 declaration path

G1 AD-40 W2 使用 src/GenomeV5/G1/DiffusionDeclarationV1.jl 的 V1 declaration domain，而不是 G1 V5 MechanismGenomePayloadV2 的外层 identity。V1 source/profile bytes 先产生下列值：

    G1_DIFFUSION_SCHEMA_SOURCE_V1
      -> g1_diffusion_schema_hash_v1()
    G1_DIFFUSION_CANONICALIZATION_SOURCE_V1
      -> g1_diffusion_canonicalization_hash_v1()
    G1_DIFFUSION_APPLICABILITY_SOURCE_V1
      + G1_DIFFUSION_PROFILE_ID_V1 + schema/canonicalization hashes
      -> g1_diffusion_profile_hash_v1()

V1 source payload 依赖：

    fresh candidate QualifiedRefV1
      + source_ref::QualifiedRefV1 + source_version
      + typed u/K/f fields
      -> G1DiffusionSourcePayloadV1
      -> source_hash = H(canonical(source_ref, source_version, u, K, f))

    candidate QualifiedRefV1 + source payload/source_hash + typed operator chain
      + closure/applicability refs + applicability domain + negative controls
      -> G1DiffusionDeclarationV1
      -> declaration_hash = H(canonical declaration body)
      -> G1DiffusionReceiptV1 (software contract-only, provider/mesh/solver/physical=0)

V1 source 本身没有 GenomeContractRef 字段或 materialization factory；它只使用 candidate_ref::QualifiedRefV1。所以 AD-40 的 public ref 必须是一个独立、可重建的 envelope 输入，不应伪装成 V1 declaration 的字段。W0 的 G1 envelope 只能引用该 V1 schema/canonicalization/profile 的 exact bytes 和显式 compatibility-profile derivation rule。GrammarProfileV2.jl、MechanismGenomePayloadV2.jl、MechanismGenomeV5.jl 的 g1_materialize_contract_ref 是另一条 V5 G1 outer-contract seam；它要求四个 V2 axes、candidate binding、grammar/applicability hashes，并不直接 materialize AD-40 V1 declaration contract。将二者混用会造成 schema-domain contradiction，结果必须 fail_closed。

### G2 metric-boundary V1 path

G2 AD-40 W2 使用 src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl 的 G2MBSourceV1/G2MBDeclarationV1，不是 FieldGeometryGenomeV5 的 V5 geometry Genome。

    G2MB_SCHEMA_DESCRIPTOR_V1
      -> g2mb_schema_hash_v1()
    G2MB_CANONICALIZATION_DESCRIPTOR_V1
      -> g2mb_canonicalization_hash_v1()
    G2MBProfileV1(profile_id, dimension=3, topology=cartesian,
                  basis_family=tensor_product, claim_ceiling=contract_only)
      -> g2mb_profile_hash_v1(profile)
      -> g2mb_profile_token_v1(profile)

G2 source payload 依赖：

    fresh public GenomeContractRef (typed G2 source candidate_ref)
      + source_ref::QualifiedRefV1 + source_version
      + chart_map + mesh + six typed faces + profile + units + authority
      -> G2MBSourceV1
      -> source_hash = H(canonical source body)

    public GenomeContractRef + G2MBSourceV1
      + g2mb_schema_hash_v1 + g2mb_canonicalization_hash_v1
      + g2mb_profile_hash_v1(profile)
      -> G2MBDeclarationV1
      -> declaration_hash = H(canonical(contract_ref, source, schema, canon, profile))
      -> G2MBReceiptV1 (mesh/provider/solver/physical=0; authority gaps remain separate)

g2mb_declaration_v1 会逐字段检查 public ref 的 schema hash、canonicalization hash 和 profile token；因此把 FieldGeometryGenomeV5 的 g2_schema_hash()/g2_canonicalization_hash() 或 g2_compatibility_profile_token(SpatialGrammarProfileV2) 塞进 G2MB V1 ref 会直接失败。V5 FieldGeometryGenomeV5 的 contract_ref 只在真正构造 V5 geometry Genome、四轴齐全并重算 candidate_hash 时使用；它不能作为 W2 的 G2MB V1 public contract。

### Candidate binding 与最终 identity

G1 的 candidate remains QualifiedRefV1；G2 的 source candidate_ref remains GenomeContractRef。二者不得 alias、URI suffix match 或互相 reinterpret。合法的 future binding envelope 只能记录：

    fresh authoring seed (new, scheduler-frozen)
      -> seed commitment / namespace token (not candidate_hash)
      -> G1 candidate QualifiedRefV1
      -> G2 common-candidate mapping input and G2 public GenomeContractRef

然后才是：

    G1/G2 typed source payloads + exact public refs + four axes
      -> layer source/declaration/binding receipts
      -> fresh same-candidate identity review
      -> only later V5 package/Genome candidate identity and candidate_hash

最终 G1 V5 identity hashes (contract_ref, payload, version_axes) in MechanismGenomeV5；G2 V5 identity hashes (contract_ref, region_interface, plan, grammar_profile, version_axes, admission) in FieldGeometryGenomeV5。这些 hashes 是 downstream outputs，不能用来选择 W0 public ref 或 W2R1 seed。public envelope 因而可以打断表面循环，同时保留 freshness，前提是 ref fields 只来自 source/profile material，candidate namespace 只来自新 seed commitment 而不是 payload 或未来 candidate hash。

## Cycle audit

| Edge | Current/required direction | Cycle status |
|---|---|---|
| schema/profile exact bytes -> public contract schema/canon/profile fields | upstream | acyclic and freezeable in W0 |
| fresh seed -> candidate namespace and G1 QualifiedRefV1 | upstream | acyclic if seed is new and not payload-derived |
| public contract envelope -> G2 G2MBSourceV1.candidate_ref | upstream | acyclic; source hash then includes the ref |
| G1 QualifiedRefV1 + typed source payload -> declaration/source hashes | downstream | acyclic |
| payload/source/declaration hashes -> candidate identity | downstream | acyclic |
| candidate identity/hash -> public ref URI or seed | forbidden | real cycle; fail_closed |
| G1 V5 g1_materialize_contract_ref <-> V1 DiffusionDeclarationV1 W2 | forbidden cross-domain edge | schema/type mismatch, not a legitimate cycle |
| G2 V5 FieldGeometryGenomeV5 ref <-> G2MB V1 source | forbidden cross-domain edge | schema/profile contradiction, not a legitimate cycle |
| G1 public ref <-> G2 public ref | no equality edge | sibling contracts; later same-candidate join only |

当前 AD-40 W2 因而被一个遗漏的 upstream materialization work order 和 V1/V5 domain 混淆阻塞；不是被不可避免的数学循环阻塞。

## Minimum additive work orders

这些是 proposed finite work orders only。本审计不 dispatch 它们，也不改变 39-task manifest。

### W0 — fresh public contract envelope materialization

Owner：Luna/high；由不同 Luna 复核 envelope。G1 和 G2 可并行准备，但各层必须使用自己的 schema/profile domain，并使用同一次 newly frozen authoring seed namespace。W0 不得原地修改 AD-40 W2 产品。

Exact products：

    docs/implementation/AD-42/W0-PUBLIC-CONTRACT-ENVELOPE/g1_public_contract_envelope.json
    docs/implementation/AD-42/W0-PUBLIC-CONTRACT-ENVELOPE/g2_public_contract_envelope.json
    docs/implementation/AD-42/W0-PUBLIC-CONTRACT-ENVELOPE/fresh_seed_binding_recipe.json
    docs/implementation/AD-42/W0-PUBLIC-CONTRACT-ENVELOPE/materialization_receipt.json

Inputs：当前接受的 G1 DiffusionDeclarationV1 和 G2 MetricBoundaryDeclarationV1 schema/profile source bytes；GenomeContractRef 与 QualifiedRefV1 type definitions；dispatch 时提供的新 scheduler-frozen authoring seed；四个 typed axis records 或 typed absence records；AD-36 sidecar policy。G1 V5 GrammarProfileV2/MechanismGenomePayloadV2 只能用于拒绝 cross-domain substitution，不能作为 V1 public contract 的输入，除非另有工作单改变 declaration domain。

Outputs：G1 public GenomeContractRef envelope（exact V1 schema/canonicalization/profile derivation）；G2 G2MB V1 public GenomeContractRef envelope；同一新 seed commitment 到 G1 QualifiedRefV1 candidate namespace 及后续 G2 common-candidate mapping input 的 recipe；materialization receipt，包含 source/profile byte hashes、exact values、type names、candidate_hash_created=false、declaration_hash_created=false、runtime call counts zero。receipt 必须明确 G2 contract 仍是 GenomeContractRef，而 G1 candidate 仍是 QualifiedRefV1。

Result union：PresentPublicContractEnvelopeV1 | AbsentPublicContractEnvelopeV1 | FailedPublicContractEnvelopeV1。Present 只代表 software contract materialization，不代表 source-backed declaration authority。缺 source/profile/axis/seed 为 typed_absent/terminal_deferred；contradiction、domain mix-up、fixture/synthetic reuse 或 candidate-hash dependency 为 fail_closed；unexpected checker fault 为 program_exception。

Dependencies：UP1-01、UP1-02、UP1-03、accepted AD-40 architecture、AD-36 sidecar contract。不得依赖 AD-40 W2 payload products、AD-37 publication、T0/T1/T2、UP2、provider、mesh、solver 或 physical evidence。可以读取 AD-40/AD-37/AD-39/AD-41 history 做 negative control，但必须拒绝把历史值当输入。

Exit gates：exact schema/profile source hash recomputation；five-field GenomeContractRef type validation；fresh seed non-reuse；G1 QualifiedRefV1 与 G2 GenomeContractRef type preservation；no candidate/payload/declaration hash dependency；JSON/path/API/control/diff validation；real PID/UTC/exit and raw streams；different Luna review。禁止 Julia/DESC/physical run。

### W2R1 — reauthor W2 against the frozen envelope

Owner：新的 Luna authoring pair，G1/G2 product directories disjoint；不同 Luna 分别复核两层及 same-seed join。W2R1 只能在新的 append-only AD-42-owned future path 或显式 versioned AD-40 W2R1 path 生成产品，绝不覆盖四个 AD-40 W2 产品。

Exact products per layer 仍是现有四-product shape：G1 和 G2 各自 candidate_declaration_payload.json 与 authoring_receipt.json。Evidence 只能进入 task-owned archive/**、review/** 或 status_sync_*/**；sidecar 不得携带 product payload。

Inputs：W0 G1/G2 envelopes and seed recipe；exact V1 G1/G2 schema/profile source bytes；fresh typed source authoring values；four axes；AD-40 architecture and AD-37 result union。W2R1 禁止复用 AD-40 W2 product、old seed、fixture、synthetic URI、legacy receipt 或 historical hash。W0 public ref 必须逐字段 copy-and-compare，不得从 payload bytes 重算。

Outputs：candidate-specific G1 V1 source payload and authoring receipt；candidate-specific G2 G2MB V1 source payload and authoring receipt；各自带 public ref envelope hash、seed recipe hash、source/profile hashes、typed candidate binding、且无 candidate hash。G2 必须保留 G2MBSourceV1 内的 public GenomeContractRef；G1 必须保留 G1DiffusionDeclarationV1 内的 QualifiedRefV1 candidate。union 仍按层为 CanonicalDeclarationSourceV1 | AbsentDeclarationSourceV1 | FailedDeclarationSourceV1。

Dependencies：W0、accepted AD-40 architecture、UP1-01/02/03、AD-36。Forbidden edges：G1<->G2 authoring dependency、AD-40 W2 product reuse、old-seed reuse、fixture/synthetic/legacy/historical-receipt、candidate identity finalization、AD-37 present promotion、T0/T1/T2、UP2、provider、mesh、solver、physical、R01-R10。Factory receipts、authority records 和 identity reviews 仍属于后续 AD-40 W3/W4。

Exit gates：W0 public ref exact equality；fresh seed recipe equality across layers；source/profile domain exactness；canonical source hash closure；G1/G2 type distinction preserved；no candidate hash；direct static validation and raw receipt；different Luna review；typed absence and fail-closed negatives。成功的 W2R1 仍只提供 software source-authoring contract evidence，不使 AD-37 present、T0 或物理 claim 为 true。

## State decision

合法下一步是 W0 -> W2R1，二者均 additive 且有界。AD-40 W2 保留为历史 AbsentDeclarationSourceV1，不原地修复。在 W0 从正确 V1 schema/profile domain 生成 fresh envelope 且 W2R1 通过独立复核前，AD-37 G1/G2 publication 仍是 proposed_blocked_external/typed absent。如果未来 authoring run 只能通过 payload/candidate hash 推导 public ref，或不能从 exact V1 profile source 定义 nonfixture compatibility-profile token，则必须返回 AbsentPublicContractEnvelopeV1/terminal_deferred，外部 blocker 继续保持。任何本地文档、测试、runner exit 或 source code hash 都不能升级 present、T0/T1/T2、provider、mesh、physical、engineering 或 R01-R10 credit。
