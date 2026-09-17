# AD44 RSDA W3-A acceptance

日期：2026-09-15  
工作单：`AD44-RSDA-W3-SOURCE-AUTHORITY-RECORDS`  
decision：`accepted_limited`  
accepted_scope：`current_working_tree_repository_design_source_software_provenance_only`

## 裁决

接受 G1/G2 两层四件 W3-A 产品的有限软件源 provenance 闭合。冻结输入和 R2
复核确认的产品 bytes/SHA 为：

- G1 record：6550 bytes，`0980aa741561445f2d66efbf828100b1df3afa24d177c54a2712fa2ed7ccb750`
- G1 receipt：3404 bytes，`3264717def0fdb1afb0ddf1213691b41a8b37d0d7f81460cb6616d5ac16e3cc2`
- G2 record：6925 bytes，`15a2479d73270fa3ef4562bc8e509404a18c61b4392d250f7f360546098eaa3e`
- G2 receipt：3596 bytes，`807950e896c342ddb2187b66364687d656ef0433469a72192e32c17c86b5506d`

两层结果均为 `RepositoryDesignSourceAuthorityRecordV1`。两个
`src/GenomeV5` 源路径在当前工作树均为 `untracked`，因此
`head_path_status=absent_untracked` 且 `head_blob_sha256=null`；它们不能被称为
committed source authority。G1/G2 当前工作树 exact bytes/SHA 仍已闭合。G2
`GenomeContractRef` 类型保持不变，没有 alias 为 `QualifiedRefV1`。

## 独立评审

R1 为 different Luna 的 `changes_requested`，其报告和 raw validation 保持
append-only；五项问题已由 W3-A 修复产品处理，R1 本身未被覆盖。

R2 为 different Luna 的 `pass_limited`，Python 3.13.5，PID `82216`，
UTC `2026-09-15T11:40:38.442522Z` 至
`2026-09-15T11:40:38.783437Z`，exit `0`，`47/47` checks。R2 确认
四件冻结产品、semantic hash、source role separation、HEAD absence truth、
G2 contract type、raw/final receipt snapshot、negative controls 和 receipt-to-record
closure 均通过。

## 限制与未关闭事项

本接受不创建或承认 candidate identity/hash、declaration hash、factory receipt、
present promotion、T0/T1/T2、provider、mesh、solver、engineering、physical、
search、R01–R10 或 L4 信用；这些字段均保持 false。W3-B
`AD44-RSDA-W3-CANDIDATE-BINDING-PROVENANCE` 继续
`proposed_blocked_common_candidate_identity_and_axis_attestation`，等待独立的
FreshCandidateBindingEnvelopeV1/common QualifiedRefV1 和四个 candidate-bound
axis attestations。不得从 seed、payload hash、axis hash、fixture、legacy 或历史
receipt 推导绑定。

## 最终状态同步证据

本 acceptance 只新增本目录的 `acceptance.md`、`manifest.json` 和
`status_sync_r1/raw/**`。最终直接校验记录 JSON/hash/path/control、R2 product
hashes、HEAD absence、G2 authoring hash、receipt snapshot、39-task DAG 和
scoped diff；Python/PID/UTC/exit/raw streams 见 manifest 与 raw sidecars。
