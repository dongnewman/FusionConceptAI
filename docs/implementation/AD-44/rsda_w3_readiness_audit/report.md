# AD-44 RSDA W3 readiness audit

日期：2026-09-15  
状态：`readiness_audit_only` / `accepted=false` / `W3_not_dispatched`  
观测 HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`

## 审计边界

本审计只判断 AD-40 后续 W3 的输入是否已经足以派发两个有限工作单：
`RepositoryDesignSourceAuthorityRecordV1`，以及其后的 candidate binding/provenance。
它不执行 W3，不生成 authority record、factory receipt、candidate binding、四轴
candidate-bound record、G2 mapping、candidate identity/hash、T0/T1/T2 或任何
provider、mesh、solver、engineering、physical、search、R01–R10 结果。没有写入
core、`task_manifest.json`、源码、测试、fixture 或既有 AD-40/AD-42/AD-43 产品。

源码、AGENTS 及 v4 README/共同合同已按项目阅读顺序检查。当前工作树有 328 行
dirty 状态；既有空间链、历史收据和其它 agent 文件均视为受保护输入。规划清单仍
为 39 tasks；AD-44 不新增 machine node。

## 已冻结的运行证据

AD-42 W2R1 的四个当前产品已经由不同 Luna 以 `pass_limited` 复核，范围仅为
software source-authoring canonical slice。当前字节与 SHA-256 为：

- G1 payload：6180 bytes，`f4841efa7e872a57e05c8eda687d951dd7775802ad3d07330947df72c5c97449`。
- G1 authoring receipt：13968 bytes，`46d7329bd83188c280208b65ac58afc571c813c9d48e3732707dcf4d4bcb4210`。
- G2 payload：7086 bytes，`7244861fa4c640035c06ac7b69623f048c17b86f9deeda71de8406c452bbcacf`。
- G2 authoring receipt：14337 bytes，`7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c`。

W2R1 独立复核 R1 的 Python 3.13.5 运行是 PID `4360`，UTC
`2026-09-15T10:42:13.799105+00:00` 至 `2026-09-15T10:42:13.809517+00:00`，
exit `0`，`47/47` checks。该复核明确保留：candidate identity 未创建、declaration
hash 为 null、G2 的 `GenomeContractRef` 类型未 alias、common-candidate mapping
仍 typed absent、attestation 仍为 `authoring_run_only`，且没有 source-backed
authority 或物理信用。

AD-43 四个 source-only axis contract products 已有不同 Luna `pass_limited`，并
闭合 exact bytes、source hash、schema/canonicalization/profile projection 和
negative controls。它们的 candidate-bound fields 仍为 null，状态仍为
`typed_absent` / `terminal_deferred`，所以只能作为 W3 的合同和 hash 输入，不能
作为已绑定的四轴证据。

AD-40 已是 `accepted_limited` 的 repository-design-source architecture boundary。
父 baseline binding 当前 `present_authority=unavailable`；T0 authority recheck
的 `present_authority_currently_allowed=false`，且其 present contract 要求 fresh
T0-owned record、candidate ref、declaration ref/hash、canonical bytes、source
receipt ref 和 trusted attestation。AD-44 不绕过这两个边界。

本审计的最终静态核验由 `D:\Users\Newman\anaconda3\python.exe` / Python
3.13.5 从仓库根直接运行，PID `42804`，UTC `2026-09-15T10:45:16.024127Z`，
exit `0`。它完成 JSON parse、canonical/no-terminal-LF、W2R1 payload/receipt
hash closure、candidate/declaration absence、W2R1 independent pass、AD-43
review presence、parent/T0 guard、39-task count、dirty-worktree observation 和
claim flags 检查；raw stdout 在本目录 `archive/validation_stdout.json`，stderr
为空 raw stream。

## 输入充分性判断

W2R1 已足以让后续 authority-record 工作单读取并封存以下内容：G1/G2 candidate
declaration payload 的 exact canonical bytes；各层 source body 的 semantic
`source_hash`；schema/factory source 的 path、bytes、SHA-256；W0 public contract
ref、seed recipe/commitment；四轴 ref/version；G2 的 typed `GenomeContractRef`；
以及 source authoring 的负控和失败收据。AD-43 另提供了四个 axis contract 的
source/schema/canonicalization/profile hash 闭合。

这些输入还缺少 authority record 必须在 W3 运行中生成的 repository-local closure：
观测 HEAD 与 path 的 exact blob/working-tree 状态、payload 与 schema/factory
source 的分层 byte receipts、authority-record 自身的 semantic hash、明确的
applicability/profile closure，以及把 AD-43 source-only axis contract hash 逐项
引用进去的不可变 receipt。W2R1 的 `source_record` 是 payload/schema source
record，不是 `RepositoryDesignSourceAuthorityRecordV1`；不能把它改名代替后者。

candidate binding/provenance 的输入尚未闭合。具体缺口是：

1. G1/G2 都写明 `candidate_identity.created=false` 且 hash 为 null；W2R1 的
   authoring candidate/ref 是 authoring slice 标识，不能被当作 final candidate
   identity，也不能由 payload 或 axis hash 反向推导。
2. G2 `common_candidate_mapping_input.target_common_candidate_ref` 为 null、
   `typed_absent`。必须有一份新的、外部于本工作单产生的
   `FreshCandidateBindingEnvelopeV1`，明确一个 common `QualifiedRefV1`，再由
   独立 mapping receipt 保留 source `GenomeContractRef` 类型并记录精确映射；
   URI 后缀相似、payload hash 或 candidate hash 推导均应 `fail_closed`。
3. W2R1 的 attestation 只有 `authoring_run_only`。AD-43 四个轴合同的
   `attestation_ref/source_record_hash/source_identity_hash/candidate_identity_hash`
   仍为 null，故不能声称四个 candidate-bound provenance axes 已存在。W3-B
   必须逐轴接收独立 attestation，缺少时输出 `Absent.../terminal_deferred`。
4. 父 baseline 与 T0 scaffolds 都只允许 typed absence/fail closed；W3-B 的
   outputs 不能直接注入 T0，也不能把 repository source authority 当作 T0-owned
   declaration authority。

因此，W3-A 的数据结构输入已基本充分，但 W3-B 仍有一个未命名的 common candidate
identity/binding envelope 输入缺口。该缺口是实际调度门，不能用 AD42 seed、AD43
source-only axis products、fixture、legacy receipt 或 AD40 旧 W2 产品填充。

## 两个有限工作单边界

### W3-A：RSDA source authority records

工作单 ID：`AD44-RSDA-W3-SOURCE-AUTHORITY-RECORDS`。G1/G2 在同一工作单内可并行，
各自只拥有以下两件产品（四件总产品）：

- `docs/implementation/AD-44/RSDA-G1-AUTHORITY-RECORD/repository_design_source_authority_record_v1.json`
- `docs/implementation/AD-44/RSDA-G1-AUTHORITY-RECORD/authority_receipt.json`
- `docs/implementation/AD-44/RSDA-G2-AUTHORITY-RECORD/repository_design_source_authority_record_v1.json`
- `docs/implementation/AD-44/RSDA-G2-AUTHORITY-RECORD/authority_receipt.json`

输入是当前冻结的 AD42 W2R1 四产品及其 R1 review、AD43 四个 axis contract 及
其 independent review、两层 GenomeV5 schema/factory source、W0 public contract
envelope/seed receipt，以及 HEAD/path/exact-byte/working-tree snapshot。输出结果
联合为：
`RepositoryDesignSourceAuthorityRecordV1 | AbsentRepositoryDesignSourceAuthorityV1 |
FailedRepositoryDesignSourceAuthorityV1`；结果必须在两层 record/receipt 中显式
标明，不得把 absence/failure 数据藏入 evidence sidecar。

依赖为 `AD-40` accepted architecture、`AD42-W2R1-REAUTHOR-FRESH-PAYLOADS`
independent `pass_limited`、`AD43-AXIS-CONTRACT-RECORDS` independent
`pass_limited`、以及 `UP1-01/UP1-02/UP1-03` 的只读合同输入。它与 parent baseline
binding、T0 recheck、G3 edit precursors 并行，不依赖 T0/T1/T2。

退出门：authority class 恰为 `repository_design_source`；payload、schema/factory
source、source body、schema/canonicalization/applicability/evidence axis bytes
分层闭合；HEAD/path/bytes/SHA 和 semantic hash 可重算；W2R1 public ref/seed 与
AD43 refs exact；缺输入为 typed absence + `terminal_deferred`，冲突为
`fail_closed`；不产生 declaration hash、candidate hash、present promotion、
factory/provider/mesh/solver/physical 调用；真实 direct JSON/hash/path/diff
receipt、PID/UTC/exit/raw streams 和不同 Luna review 齐全。

禁止边：W3-B binding/provenance、factory receipts、identity review、AD37
publication、T0/T1/T2、UP2、任何 provider/mesh/solver/physical/search/R credit；
禁止修改 core、task manifest、源码、测试、fixture 和 AD42/AD43 产品。清理仅限
本单自有临时文件，sidecar 仅在 `archive/**`、`review/**` 或 `status_sync_*/**`。

### W3-B：candidate binding and provenance

工作单 ID：`AD44-RSDA-W3-CANDIDATE-BINDING-PROVENANCE`。它只能在 W3-A 两层 record
和 receipt 冻结后、且另有 fresh common candidate binding envelope 后执行。精确产品
为八件：

- `docs/implementation/AD-44/RSDA-G1-CANDIDATE-BINDING-PROVENANCE/candidate_binding.json`
- `docs/implementation/AD-44/RSDA-G1-CANDIDATE-BINDING-PROVENANCE/provenance_axes.json`
- `docs/implementation/AD-44/RSDA-G1-CANDIDATE-BINDING-PROVENANCE/binding_receipt.json`
- `docs/implementation/AD-44/RSDA-G2-CANDIDATE-BINDING-PROVENANCE/candidate_binding.json`
- `docs/implementation/AD-44/RSDA-G2-CANDIDATE-BINDING-PROVENANCE/provenance_axes.json`
- `docs/implementation/AD-44/RSDA-G2-CANDIDATE-BINDING-PROVENANCE/g2_candidate_mapping_receipt.json`
- `docs/implementation/AD-44/RSDA-G2-CANDIDATE-BINDING-PROVENANCE/binding_receipt.json`
- `docs/implementation/AD-44/RSDA-SAME-CANDIDATE-JOIN/cross_layer_join_receipt.json`

输入是 W3-A 的四件冻结产品、fresh public `GenomeContractRef`、一份独立提供的
`FreshCandidateBindingEnvelopeV1`/common `QualifiedRefV1`、四份 candidate-bound
axis records 及独立 attestations。当前这些最后两类输入不存在；因此本单状态应
为 `proposed_blocked_common_candidate_identity_and_axis_attestation`，本审计不派发
它，也不制造 envelope、mapping 或 identity。

结果联合为：
`CandidateBoundRepositorySourceProvenanceV1 |
AbsentCandidateBoundRepositorySourceProvenanceV1 |
FailedCandidateBoundRepositorySourceProvenanceV1`。G2 mapping 必须明确记录
`GenomeContractRef -> QualifiedRefV1` 的 source/target 类型、exact public ref、
algorithm/profile hash、candidate binding 和 independent review；不能 alias。
四个轴必须分别绑定同一 fresh candidate/source record，缺失为
`Absent.../terminal_deferred`，layer/ref/hash/attestation 冲突为
`Failed.../fail_closed`。

退出门：W3-A exact frozen inputs；fresh envelope exact equality；四轴独立 attestation
齐全；G1/G2 same-candidate join 通过；source changes force a new identity; no
payload/declaration/axis hash is used to derive candidate identity; no final candidate
hash is created by this work order; direct receipt、different-Luna identity-input
freeze 和 append-only cleanup 完整。

禁止边：factory receipts、fresh identity review as a promotion, AD37 publication、
T0 authority recheck、T1/T2、UP2、provider/mesh/solver/physical/search/R01–R10。
它不能把自身生成的 binding 当作 T0 authority，也不能把 current parent baseline
typed absence CAS 到 present。

## 裁决

AD-44 只接受为 `readiness_audit_only`，不接受任何实现或 authority claim。W2R1
独立 `pass_limited` 门已观测满足，故 W3-A 的有限边界可以在父任务审查后进入调度；
W3-B 明确保持 blocked，直到一个独立来源提供 common candidate binding envelope
和四个 candidate-bound axis attestations。所有 present declaration、T0/T1/T2、
provider、mesh、solver、engineering、physical、search 和 R01–R10 仍为 false。
