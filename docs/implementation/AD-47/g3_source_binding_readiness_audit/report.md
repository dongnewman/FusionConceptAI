# AD-47 G3 source-backed declaration and binding readiness audit

日期：2026-09-15  
状态：`readiness_audit_only`  
验收：`accepted=false`  
范围：三层 Genome 主线的 G3 source-backed declaration、source authority、candidate binding、四轴 provenance、feedback authority 与可编辑 realization/control 反馈边界。

本审计只读取合同、源码、测试、既有 receipts 和工作树状态，并新增本目录的报告、manifest、cleanup inventory 及 `archive/**` 原始收据。没有实现、修改 `src/`、`test/`、fixture、核心规划、`task_manifest.json` 或既有产品；没有生成 G3 candidate/declaration/final identity hash，没有运行 T0/T1/T2、provider、mesh、solver、物理、搜索或 R01–R10 验收。

## 定点基线与运行证据

仓库根为 `D:\006-Programing\LMC\FusionConceptAI`，HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`。审计时工作树有 331 条既有 dirty 状态；全部保留。受保护的 Python/Julia 进程未被触碰。本单使用 `D:\Users\Newman\anaconda3\python.exe`，Python `3.13.5`，审计 PID `87344`，UTC `2026-09-15T11:52:02.006342+00:00`；原始 JSON 输出在 `archive/validation_stdout.json`，stderr 在 `archive/validation_stderr.txt`。

规划校验重新执行并通过：`31` 个 markdown、`497` 个相对链接、`39` 个任务、DAG acyclic，exit `0`。相关源码和 AD-39–AD-46 作用域 `git diff --check` exit `0`；其警告只涉及既有 LF/CRLF，不是本审计产品错误。文档/清单校验和 diff 校验只证明工程卫生，不能充当物理或工程证据。

冻结输入的只读复核显示：AD-42 W2R1 G1/G2 payload 仍分别为 `6180/f4841efa7e872a57e05c8eda687d951dd7775802ad3d07330947df72c5c97449` 和 `7086/7244861fa4c640035c06ac7b69623f048c17b86f9deeda71de8406c452bbcacf`；AD-43 四个 source-only axis contract 的 SHA-256 仍为 `f16a518f...ad1993`、`0b68dd...54d5a`、`1ca17e...2902d19`、`699291...2a5a98`。这些产品 canonical JSON、无末尾 LF，但 G1/G2 candidate-bound 字段仍为空/typed absent。

AD-44 W3-A 四件 authority record 已由 root 以 `accepted_limited` 接受并冻结；范围仅是当前 untracked working-tree 的 software repository-source provenance。它不提供 committed HEAD source、candidate、declaration authority 或 physical credit。AD-45 fresh `QualifiedRefV1` handle 已有不同 Luna R2 `pass_limited`、`59/59`，并由 root 接受为 `accepted_limited` 的临时 join handle；它仍不能成为最终 candidate identity。AD-45 G1/G2 candidate-bound axis 产品不存在。AD-46 identity products 也不存在。AD-45 R1 和五份旧失败 raw 均 append-only 保留。

## G3 现状与缺口

以下三类事实必须分开记录：

| 层面 | 已观察到的能力 | 当前上限 |
|---|---|---|
| G3 V5 contracts | `RealizationGenomeV5`、`ControlGenomeV5`、`CoupledRealizationControlBindingV2`、四轴、typed ports/resource/ledger/fault/feedback schema 和 fail-closed admission 源码存在 | 合同/结构 admission；`provider_match`、source authority、工程和物理仍未闭合 |
| realization/control editable precursors | realization-only 与 control-only source body、replacement/edit operation、独立 state/content/operation hash 和 failure-atomic CAS 代码及 focused receipts 存在；各自 machine node 仍 `accepted=false`/`review_pending` 上限，local software precursor 才可接受 | 可编辑软件合同；没有同一 fresh candidate 的 source-backed declaration、factory receipt 或 physical realization |
| binding/feedback precursor | binding child 的 `AbsentChildBindingV1`、`authority_recheck_not_published`、`terminal_deferred`、失败原子性和 G1/G2 pairing negative controls 已接受为 local typed-absence precursor；`G3SourceFeedbackLawV1` 只定义接口/账本和 external authority gap | 没有 `PresentChildBindingV1`、同候选 G1/G2/G3 join、feedback authority receipt、source/control/realization child identity |

源码中的 `RealizationControlGenomeV5` 会计算一个 bundle `candidate_hash`，但该值是当前软件对象的 canonical contract hash，不能被解释为父目标的三层 `CandidateIdentityV1`、source-backed declaration hash 或物理 subject hash。G3 fixtures 中的 candidate/ref、feedback target 和 provider values 是测试输入；它们不能提升 authority。G3 binding 的 direct present constructor/factory 仍以 `binding_authority_typed_absent` 拒绝，`complete=true` 也保持 typed absence；parent baseline/T0 scaffolds 的 present promotion 和 absent-to-present CAS 仍 fail closed。

因此，当前缺口不是“再补一个字段”：至少还缺三层 G3 source bytes 的 candidate-bound factory receipt、G3 各 child/bundle 的 source/declaration/content hash闭合、独立 source identity review、显式 G2 `GenomeContractRef`→common `QualifiedRefV1` mapping、G3 四轴 candidate attestations、realization/control/binding child join、feedback target authority 与 source implementation error 回流接口。AD43 现有 axis schema 的 `layer` 仅允许 `G1|G2`，不能直接承载 G3 scope；必须先增加独立、additive、版本化的 G3 adapter/schema。未闭合时必须维持 `Absent...`/`terminal_deferred` 或冲突时 `Failed...`/`fail_closed`。

## 最早可执行的有限工作单

下面工作单是可在父任务审查后进入调度的候选边界，不是本审计已派发的实现。每单由 `gpt-5.6-luna/high` 实现，另一个不同的 `gpt-5.6-luna/high` 独立复核；heavy Julia/DESC/mesh/solver lane 不启动。W0 是最早的前置合同工作；W1 不依赖 W0 的 G3 axis adapter，可在 AD45 A 已接受、AD44 W3-A 已冻结后并列派发；W2 必须等 W0 与 W1；W3 必须等 W2 及 child/control/feedback 输入。

### AD47-G3-AXIS-SCHEMA-VERSIONED-EXTENSION

这是最早、可独立执行的 G3 axis 合同前置工作，状态 `proposed_ready_after_parent_review`。它不得修改 AD43 四个冻结产品，不得修改 `default_operator_registry()`，也不得把 G3 scope alias 成 AD43 的 `G1|G2`。它应复用 AD43 通用字段名、canonicalization/JSON 规则和负控语义，但增加 G3 专属 schema/ref/version，显式记录 `layer=G3` 与 `scope ∈ {realization,control,binding,bundle}`。

- 文件归属和数量：4 件 JSON 产品，`docs/implementation/AD-47/G3-AXIS-SCHEMA-VERSIONED-EXTENSION/` 下 `g3_axis_schema_v1.json`、`g3_axis_scope_contract_v1.json`、`g3_axis_migration_receipt.json`、`g3_axis_validation_receipt.json`；raw 和失败历史只能在该任务 `archive/**`。
- schema/version：`G3CandidateAxisSchemaV1`，独立 ref `fusionconceptai://GenomeV5/G3/axis-contract`，schema version `v1`，canonicalization profile 显式复用 AD43 profile version 并保留 G3 adapter version；scope enum 为四个 G3 scope，四轴字段与 AD43 common fields 一一对应，不能扩展 AD43 的 layer enum。
- 输入：AD43 四个冻结 source-only contracts、AD43 hash/path receipt、G3 四个 `GenomeContractRef`/四轴定义、G3 source/child contract schema、共同合同和 AD45/AD44 边界。AD43 输入只读；不得读取 AD45 seed、candidate hash 或生成 common ref。
- 输出 union：`PresentG3AxisSchemaExtensionV1 | AbsentG3AxisSchemaExtensionV1 | FailedG3AxisSchemaExtensionV1`。Present 只表示 additive schema/adapter closure，不表示 candidate-bound attestation；缺输入为 `Absent...` + `terminal_deferred`，layer/version/alias/hash 冲突为 `Failed...` + `fail_closed`。
- 依赖/禁止：依赖 AD43、G3 contracts；禁止改 AD43 products、G3 source files、registry、candidate/declaration/final identity hash、T0/T1/T2、provider/mesh/solver/physics/search/R01–R10。只允许本单四件产品及 archive raw。
- 退出门：四 scope 和四轴字段可机器解析；AD43 原始 bytes/SHA 未改变；G3 layer 不进入 AD43 G1/G2 enum；canonical replay、JSON/hash/path/control、39-task DAG、scoped diff、失败历史、不同 Luna 复核和 task-owned cleanup 完整。

### AD47-G3-SOURCE-AUTHORITY-RECORDS

这是在当前根裁决下最早可派发的 G3 source-backed slice，状态 `proposed_ready_after_parent_review`；它与 W0 并列，不依赖 G3 axis adapter。它依赖 AD-45 A 已由 root 接受的 `accepted_limited` 临时 handle、AD-44 W3-A root 冻结和当前 G3 source paths；若任一输入发生变化，回到 `blocked`。

- 文件归属和数量：8 件 JSON 产品，目录 `docs/implementation/AD-47/G3-SOURCE-AUTHORITY-RECORDS/`；每个 `realization`、`control`、`binding`、`bundle` 各一份 `source_authority_record_v1.json` 和 `authority_receipt.json`。raw 失败/运行收据只能在该任务的 `archive/**`。
- 输入：当前四个 G3 contract refs/四轴定义；`src/GenomeV5/G3/RealizationGenomeV5.jl`、`ControlGenomeV5.jl`、`CoupledRealizationControlBindingV2.jl`、`G3SourceFeedbackLawV1.jl`；`G3RealizationChildEditabilityV1.jl` 及其 `g3_realization_child_editability_v1_tests.jl` 和最终 focused/status receipts；`G3ControlChildEditabilityV1.jl` 及其 `g3_control_child_editability_v1_tests.jl` 和 R9/status receipts；`G3BindingChildEditabilityV1.jl`、fixture、static QA、70/70/status receipts；AD-45 R2 envelope/receipt；AD-44 W3-A 四件冻结 record/receipt；显式 source locator、factory identity、fresh candidate ref 与 G3 child layer。
- 输出 union：record 的 `PresentG3SourceAuthorityRecordV1 | AbsentG3SourceAuthorityRecordV1 | FailedG3SourceAuthorityRecordV1`；receipt 的独立 `G3SourceAuthorityReceiptV1 | AbsentG3SourceAuthorityReceiptV1 | FailedG3SourceAuthorityReceiptV1`。Present record 必须记录 raw source SHA、semantic body SHA、declaration/content SHA、exact candidate ref、contract ref、four axes、factory receipt、trusted attestation；receipt 必须逐字段闭合 record path/bytes/SHA、source locator、factory identity、result union、candidate ref/type、failure semantics、no-publish 和 execution metadata。缺输入为 typed absent/`terminal_deferred`，层/ref/hash/receipt 冲突为 failed/`fail_closed`。
- 禁止：从 fixture、AD-42 seed、W2R1 payload/ref、URI、当前 bundle candidate hash、旧 receipt 或自身 hash 派生 common ref/declaration hash；不得创建最终 `CandidateIdentityV1`，不得写 T0/T1/T2、UP2、provider/mesh/solver/engineering/physical/search/R01–R10；不得改 core、task manifest、既有 AD42–46 products、旧 registry 或 default operator registry。
- 退出门：四个 G3 source locator/factory 真实可重放；source bytes、canonical semantic body、candidate binding、G3 child contract/type、四轴和 receipt 字节逐字段闭合；source mutation 生成新 identity input；缺失/冲突 union 精确；direct JSON/hash/path/control、PID/UTC/exit/raw、different-Luna review 和 task-owned cleanup 全部留证。

### AD47-G3-CANDIDATE-BOUND-AXIS-ATTESTATIONS

依赖 W0、W1 全部 required present/明确 absent 结果、AD-45 A、AD-44 W3-A、独立 source identity review 和 G2 mapping；在这些条件满足前 `blocked`。按四个 G3 scope（realization/control/binding/bundle）各做四轴，共 16 件 JSON 产品。

- 文件归属和数量：`docs/implementation/AD-47/G3-CANDIDATE-BOUND-AXES/<scope>/` 下每个 scope 的 `payload_schema_attestation.json`、`canonicalization_profile_attestation.json`、`applicability_profile_attestation.json`、`evidence_receipt_attestation.json`，共 16 件；raw 只在 `archive/**`。
- 输入：W0 的 `G3CandidateAxisSchemaV1`/scope mapping、W1 source authority records/receipts、AD-45 R2/root accepted common `QualifiedRefV1`、每个 G3 scope 的 exact `GenomeContractRef`/axis refs、fresh G3 source identity review、显式 G2 mapping、W2R1/AD43 read-only contracts。candidate identity hash 只能由独立 identity owner 输入，不能由本单生成。
- 输出 union：`CandidateBoundG3ProvenanceAxisAttestationV1 | AbsentCandidateBoundG3ProvenanceAxisAttestationV1 | FailedCandidateBoundG3ProvenanceAxisAttestationV1`。Present 必须精确绑定 common ref、scope ref、source/declaration/attestation/fresh receipt hashes；缺失是 typed absent/`terminal_deferred`，冲突/错层/旧候选/seed alias 是 failed/`fail_closed`。
- 退出门：四 scope 的四轴完整且同一 common ref；G2 source type 保持 `GenomeContractRef`；每个 hash 可独立重算；source/child change 强制新输入；不同 Luna 复核通过。不得生成 final identity、T0/T1/T2 或物理 credit。

### AD47-G3-CHILD-BINDING-FEEDBACK-JOIN

依赖 W0、W1、W2；这是可编辑能力和物理反馈的首个 join slice，不等于 realization 闭环验收。

- 文件归属和数量：6 件 JSON 产品，`docs/implementation/AD-47/G3-CHILD-BINDING-FEEDBACK-JOIN/` 下 realization/control/binding 三个 child 的 `child_join_receipt.json` 与 `feedback_authority_receipt.json`；negative controls 和 raw receipts 只能在 `archive/**`。
- 输入：同一 fresh candidate 的 G3 三 child refs、bundle ref、16 轴 attestation、显式 G2 mapping、source identity reviews、`G3FeedbackChannelV2` target contracts、realization/control editable state hashes、resource/thermal/implementation-error ledger 和 fail-atomic operation lineage。
- 输出 union：child join 的 `PresentG3ChildJoinReceiptV1 | AbsentG3ChildJoinReceiptV1 | FailedG3ChildJoinReceiptV1`；feedback receipt 的独立 `PresentG3FeedbackAuthorityReceiptV1 | AbsentG3FeedbackAuthorityReceiptV1 | FailedG3FeedbackAuthorityReceiptV1`。Present 只能表示 software join/feedback authority receipt；source implementation error、loss、heat、shape 的单位、方向、时间/空间支撑和 owner ledger 必须完整；缺 provider/authority/closed loop 为 absent/`terminal_deferred`，冲突为 failed/`fail_closed`。
- 退出门：同 candidate、同 layer、同 source/content/state lineage；feedback 目标 authority 明确，编辑后旧 receipt 失效且 CAS 失败保持 prior bytes/state/history 不变；不得把 feedback receipt 当物理回代、solver convergence、工程通过或 final authority。

## 结论与父目标边界

AD-47 最终结论为 `readiness_audit_only`、`accepted=false`、`G3_source_backed_ready=false`。G3 软件合同和 editable typed-absence precursors 可作为后续实现输入；实际 G3 source-backed declaration、authority、candidate binding、四轴 attestations、child identity、feedback authority 和逆向 realization 仍未闭合。AD-45 A 修复和独立复核是最先的无关依赖门；其后应先取 fresh G3 source authority，再做 axes 和 child/feedback join。任何 partial present、fixture/runner/test/documentary result 或 local hash 都不提升 T0/T1/T2、provider、mesh、solver、engineering、physical、search、R01–R10 或 L4。
