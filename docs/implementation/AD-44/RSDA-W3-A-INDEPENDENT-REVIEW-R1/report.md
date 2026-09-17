# AD-44 RSDA W3-A independent review R1

日期：2026-09-15  
范围：`AD44-RSDA-W3-SOURCE-AUTHORITY-RECORDS` 的四件冻结产品。  
结论：`changes_requested`；W3-A 不可按当前 receipts 直接接受，W3-B 继续
`proposed_blocked_common_candidate_identity_and_axis_attestation`。

## 独立输入与边界

本复核从工作树重新读取四件产品、AD-40 authority architecture/acceptance、
AD-42 W2R1 payload/review、AD-43 axis contracts/review、AD-44 readiness audit、
`AGENTS.md`、v4 README/共同合同与当前 task manifest。未信任实现者的汇总，未修改
四件被审产品、AD-42/AD-43 输入、源码、测试、fixture、core、task manifest 或其它
任务文件。只写入本目录的 report、manifest 和 `review/**` raw sidecars。

四件产品的当前字节和 SHA-256 与工作单给定值一致：

| layer | product | bytes | SHA-256 |
|---|---|---:|---|
| G1 | `repository_design_source_authority_record_v1.json` | 6410 | `05c26a883441b99e729346e72beef42ef3c5c1245b496a8d9ab7006f77cb1afe` |
| G1 | `authority_receipt.json` | 3149 | `bbd23ea50fc4e3200d42a4859bab612ff1bb07a442cf09826d90a88eebb35cf4` |
| G2 | `repository_design_source_authority_record_v1.json` | 6787 | `0cb67cade7e8d36c7240c130eccc5e0c8ab9552f96f05a890d65d14804b01021` |
| G2 | `authority_receipt.json` | 3341 | `787f4a81f67113a6724165e49a898558691eb3a8fddc097f4e11cda15374abb2` |

四件文件均可解析为 JSON、无 terminal LF，且 exact bytes 等于 UTF-8 compact
lexicographic canonical JSON。G1 semantic hash
`30331992f34f20e3caaabf9625711fbd566d073f642689e51a04d9183e877f14`、G2 semantic
hash `c3adc3ddc1402024c4a8b6df2c9324bb4745c6db2cf60126acadce1ced8e1675` 均可由
record 去除 `semantic_hash` 后重算。

## 独立核验结果

独立 Python 3.13.5 运行 PID `65392`，UTC
`2026-09-15T11:25:54.151358Z`–`2026-09-15T11:25:54.640953Z`，退出码 `1`，
`104/109` checks。原始 stdout 与空 stderr 在 `review/` 保存。规划验证器为
`39 tasks`、DAG acyclic、exit `0`；全局 `git diff --check` exit `0`。

已通过的核心边界包括：`repository_design_source` class、software-only claim
ceiling、payload/schema-factory/source-body 三角色分离、candidate/declaration
hash 缺失、candidate-bound attestation typed absence、所有 provider/mesh/solver/
engineering/physical/search/T0/T1/T2/R01-R10 flags 为 false、G2
`GenomeContractRef` 类型保持独立、AD-43 引用与大部分 W0/W2R1 hashes 可重算，
以及 negative controls 的 fail/absent union。

## 必须修复的五个闭环缺口

1. G1 与 G2 source role 都写了 `head_blob_sha256`，但当前路径在工作树为 `??`，
   `git cat-file -e HEAD:<path>` 对两层均失败；HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`
   中没有这两个 blob。当前字节 SHA 可以重算，但不能作为 HEAD blob receipt。
   应明确记录 untracked/no-HEAD 状态或提交后重新取证，不能保留误导性的
   `head_blob_sha256` claim。
2. G2 record 的 `inputs.authoring_receipt` digest 是 66 字符并与实际文件 SHA 不同：
   record 写入 `7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bedbd6e2f9eb59d1b29cd988c`，
   实际文件为 `7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c`。
   这是输入闭合失败，必须修正 record 后重算其 semantic hash、receipt 引用和所有
   dependent raw evidence。
3. G1 raw validation stdout 的 `details.G1.receipt_bytes/sha256` 仍是
   `2912`/`45de0bb5...a0b2b`，而当前 G1 receipt 是 `3149`/
   `bbd23ea5...35cf4`；因此 raw receipt snapshot 不是当前冻结产品的证据。
4. G2 raw validation stdout 的 `details.G2.receipt_bytes/sha256` 仍是
   `3104`/`b4ebe492...560e4`，而当前 G2 receipt 是 `3341`/
   `787f4a81...4abb2`；同样必须在产品修复后重新运行并替换为匹配的 raw stream。
5. 修复必须保持四件产品 exact count、canonical/no-LF、semantic hash、W0/AD43
   refs、negative controls 和所有 claim ceiling；不能通过生成 candidate hash、
   declaration hash、present promotion 或 T0/T1/T2 来规避闭环失败。

这些问题均是可复核的产品/receipt 闭合问题，不是物理结果，也不改变当前
software-only 证据上限。

## W3-B 阻塞保持

未发现 `FreshCandidateBindingEnvelopeV1`、common `QualifiedRefV1`、四个
candidate-bound axis attestations 或 W3-B 八件产品。G2 的 `GenomeContractRef`
不能 alias 为 `QualifiedRefV1`；seed、payload hash、axis hash、fixture、legacy 或
历史 receipts 不能推导 common candidate identity。故 W3-B 仍必须保持
`proposed_blocked_common_candidate_identity_and_axis_attestation`，不转移任何
source authority、candidate identity、T0、provider、mesh、solver、physical 或
R01–R10 credit。

## 复核裁决

当前 verdict 为 `changes_requested`。修复上述五项后，使用不同 Luna 重新从四件
产品和新的 raw receipts 复核；在此之前 W3-A 不得记为 accepted_limited，亦不得
派发 W3-B。
