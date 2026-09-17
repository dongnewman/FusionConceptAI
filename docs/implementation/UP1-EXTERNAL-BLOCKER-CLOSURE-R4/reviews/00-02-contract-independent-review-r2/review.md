# 00–02 contract independent review r2

审查范围：R1 的 2 个 P1 + 2 个 P2 修复，以及 R4 当前 00 external-delta、01 external-input、02 integration contract。审查只读；本目录是唯一写入位置，未修改被审合同、生产源码或测试。

## 最终裁决

**`PASS_BOUNDED_OFFLINE_INTEGRATION_AUTHORIZATION`**。

合同层面的 R1 阻断已闭合，可以授权**离线、无外部权威的集成测试**，但授权上限仅为结构/绑定/失败分类/锁和两阶段 adapter seam 的测试。当前 R4 仍明确为 `contract_draft` / `not_implemented` / preparation-only：不得把离线测试当作外部验证，不得产生 `externally_verified`、T0/T1/T2、formal credit、authority credit 或 publication。

## R1 问题复核

### P1-001 hash/bytes freeze — CLOSED

独立按 `02-integration-contract/file-hash-manifest.json` 重算，15/15 listed files 存在且 bytes 与 SHA-256 全部一致，0 mismatch、0 missing。修复后的 manifest 已包含 R1 三个漂移文件的新 bytes/hash。详见 `raw/hash_check_r2.raw.json`。

### P1-002 EXTERNAL_ISSUED seam — CLOSED at contract level, implementation intentionally absent

R4 现在把 `EXTERNAL_ISSUED` 明确限定为 raw input label，正向路径被完整写成：本地结构/joins → 独立 external-authority adapter → `externally_verified`；adapter 必须验证 pinned trust root、ordered chain、signature、trusted time、revocation、freshness/replay、candidate/source/run、G2 和独立复核，并保留 raw bytes/receipts。`TEST_ONLY`、local fixture、local spool/CAS、system trust store、historical receipt 和 local product 明确永远不能升级。

当前 prototype 仍返回 `external_material_not_supported`，且没有 R4 adapter 实现；合同已把这一点标成“未实现/不可用”，而非把拒绝结果伪装成 positive route。故这是可测试的未来 seam，不是当前 positive evidence。任何要求真实 `externally_verified` 的测试不在本授权内。

### P2-001 扫描范围措辞 — CLOSED

00 scan 明确限定为 2 roots × 7 frozen relative paths = 14 root/path pairs，并声明 remote channels、unlisted paths 未查询、结论仅是该时间点“未观察到”。因此 `typed_absent=26/26` 不再被表述为全球不存在外部响应。

### P2-002 trust taxonomy — CLOSED

`typed_absence`、`invalid`、`unverified` 已定义为互斥：缺材料/能力 → `terminal_deferred`；已存在且证明矛盾 → `fail_closed`；字节可用但外部 authority/独立复核未完成 → `unverified` + `terminal_deferred/non_evidence`。明确禁止把 `invalid` 降级为 absence/unverified，也禁止 local/TEST_ONLY 升级。

## 当前快照和 26/26 复核

- 01 JSON：26 items、26 unique IDs、26/26 `current_typed_state=typed_absent`；所有 26 个 `authoritative_channel` 的 state/owner/endpoint/transport/authentication/ack 均为 `typed_absent`。
- 当前外部快照：`usable_external_inputs=0`、G1/G2/G3=`typed_absent`、`admitted_candidate=typed_absent`、`terminal_deferred`、`publish=false`、`formal_credit=none`、`authority_credit=false`。
- 06 predicate 独立序列两次均为 26/26，exit 0、`all_no_publish=true`、每个 vector `no_publish=true`，覆盖 R01–R25 + D01；其 claim ceiling 为 `prototype_test_only`，不是 authority evidence。

## 范围、序列和锁

00 scan 的控制项保持 `new_ad=false`、`s3_rerun=false`、`network_accessed=false`、`external_request_sent=false`、`source_or_test_modified=false`。合同的唯一正式顺序是 `T0 snapshot → external-input recheck gate → T1 → T2`；缺失、失败、过期或未验证输入返回 unchanged T0 + `terminal_deferred`/`fail_closed`。G8/G9 未满足时 `T1_go=false`、`T2_go=false`。

## 授权边界

允许：离线运行合同/adapter seam 的 schema、raw-byte/CAS、cross-binding、all-or-reject、failure-taxonomy、TEST_ONLY non-evidence、no-publish/no-credit 和两次重放测试。

不允许：发送外部请求、读取或推断外部 authority、生成/升级 `externally_verified`、T0 recheck、T1/T2、AD、新 S3/solver/Julia/DESC、publication 或任何 formal/authority credit。

结论：R1 的 P1/P2 在**合同审查层面**均已闭合；可授权上述受限离线集成测试。离线测试通过不关闭 UP1 external blocker，也不改变 parent goal 状态。
