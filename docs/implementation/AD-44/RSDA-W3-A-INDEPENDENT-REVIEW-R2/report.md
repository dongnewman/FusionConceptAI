# AD-44 RSDA W3-A independent review R2

日期：2026-09-15  
范围：修复后 `AD44-RSDA-W3-SOURCE-AUTHORITY-RECORDS` 四件冻结产品。  
结论：`pass_limited`，仅限 software source provenance；不授予 candidate、T0/T1/T2、
provider、mesh、solver、engineering、physical、search 或 R01–R10 信用。

## 独立复核

本复核重新读取 AD-44 W3-A 四件产品、AD-40 authority architecture/acceptance、
AD-42 W2R1 payload/review、AD-43 axis contracts/review、AD-44 readiness、
`AGENTS.md`、v4 README/共同合同及 task manifest。没有修改被审产品、AD-42/AD-43
输入、源码、测试、fixture、core 或 task manifest；只写入本 R2 目录。

四件产品冻结字节与给定值完全一致：

| layer | product | bytes | SHA-256 |
|---|---|---:|---|
| G1 | `repository_design_source_authority_record_v1.json` | 6550 | `0980aa741561445f2d66efbf828100b1df3afa24d177c54a2712fa2ed7ccb750` |
| G1 | `authority_receipt.json` | 3404 | `3264717def0fdb1afb0ddf1213691b41a8b37d0d7f81460cb6616d5ac16e3cc2` |
| G2 | `repository_design_source_authority_record_v1.json` | 6925 | `15a2479d73270fa3ef4562bc8e509404a18c61b4392d250f7f360546098eaa3e` |
| G2 | `authority_receipt.json` | 3596 | `807950e896c342ddb2187b66364687d656ef0433469a72192e32c17c86b5506d` |

四件文件均 JSON canonical、compact、lexicographic、无 terminal LF。G1 semantic hash
为 `079ff8f3076e27fee3fd8b4b4646d646c9426ef816a16ae1aaa1d7fc2e0521d1`，G2 semantic
hash 为 `1cb9cc4e5c93a25190a413948ddb5b16867a87dd9b2cd0641f8d6cdf4672be7a`，均由
record 去除 `semantic_hash` 后独立重算匹配。record 对 receipt 的 bytes/SHA/semantic
hash 引用均匹配当前产品。

## R1 五项修复闭合

1. 两层 source 路径在 HEAD `4b69f55f7f80240147a65a22809dc1207824dde2` 中确实不存在；
   `head_blob_sha256=null`、`head_path_status=absent_untracked`、工作树状态
   `untracked` 与 `source_path_status=absent_untracked` 一致。当前工作树字节长度与
   SHA-256 仍独立闭合，未把工作树 SHA 冒充 HEAD blob。
2. G2 authoring receipt 已闭合为 14337 bytes 与 64-hex SHA
   `7a68be8d2e24b6a15364800cb3855c6a3d80b6d03bed6e2f9eb59d1b29cd988c`；G1 的
   13968 bytes 与 SHA `46d7329bd83188c280208b65ac58afc571c813c9d48e3732707dcf4d4bcb4210`
   也匹配。record 的 `@bytes#sha` 形式可重算。
3. G1 `archive/final_receipt_snapshot.json` 匹配最终 receipt：3404 bytes，
   `3264717def0fdb1afb0ddf1213691b41a8b37d0d7f81460cb6616d5ac16e3cc2`。
4. G2 对应 snapshot 匹配最终 receipt：3596 bytes，
   `807950e896c342ddb2187b66364687d656ef0433469a72192e32c17c86b5506d`。
5. final validation stdout 明确省略 receipt 自身 bytes/SHA，并标注
   `receipt_self_hash_excluded=true`；snapshot 在 receipts 外部且未被 receipt 引用，
   因此没有自引用循环。R1 的失败 stdout 仍保留在原 archive。

## 角色、合同与负控

G1/G2 authority class、software-only ceiling、payload/schema-factory/source-body 三
角色分离、W0 和 AD-43 refs、四轴 source-only/typed absence、candidate/declaration
hash absence 及所有 claims false 均通过。G2 的 `GenomeContractRef` 保持其类型，
没有 alias 为 `QualifiedRefV1`。负控、工作树路径/SHA、raw stdout/stderr 以及
receipt-to-record closure 均通过；独立运行 Python 3.13.5 PID `82216`，UTC
`2026-09-15T11:40:38.442522Z`–`2026-09-15T11:40:38.783437Z`，`47/47`，exit `0`。

`validate_plan.py` exit `0`，39 tasks 且 DAG acyclic；scoped `git diff --check` exit
`0`。原始 stdout 与空 stderr 记录于 `review/`。

## W3-B 状态

W3-B 八件产品、`FreshCandidateBindingEnvelopeV1`、common `QualifiedRefV1` 和四个
candidate-bound axis attestations 仍不存在。G2 mapping 仍不得从 seed、payload hash、
axis hash、fixture、legacy 或历史 receipt 推导。故 W3-B 继续保持
`proposed_blocked_common_candidate_identity_and_axis_attestation`。

本次 `pass_limited` 只接受 W3-A 的软件源证据闭合，不改变父目标 R01–R10 或任何
物理/工程验收状态。
