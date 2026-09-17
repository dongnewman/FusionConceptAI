# 00–02 contract independent review r1

审查时间：`2026-09-17T01:39:03.4296938Z`（只读）。本审查只写本目录，未修改被审合同、代码或 tests。

## 总裁决

`REJECT_FOR_INTEGRATION`：00 external delta 与 01 external-input contract 的“当前无外部材料”结论在其观测时间和声明上基本自洽；但 02 integration contract 目前有两个 P1 阻断，不能作为可接受的 integration package。没有发现 P0；也没有发现伪造的具体 owner、endpoint 或 external authority credit。

当前安全上限仍应保持：`typed_absent -> terminal_deferred`、`formal_credit=none`、`authority_credit=false`、`no_publish=true`，且不得新建 AD、重跑 S3 或改变 39-DAG/R01–R10。

## 逐项审查

### 00 external delta — PASS（带时间范围说明）

- `scan_summary.md:5-9, 24-32` 与 raw path/frozen scans 一致：26/26 `typed_absent`，0 usable/new candidate，`new_ad=false`、`s3_rerun=false`；九项冻结 project inputs 同时有 raw SHA-256 与 Git blob OID match。
- 14 个 checked root/path 为空，且系统证书库只作本地观察；文件明确禁止把系统 trust store、历史 receipt、local spool/CAS 或本地环境 hash 当 external authority。因此没有把本地实现冒充 external authority。
- 限制：scan 只证明 `2026-09-17T01:20:56Z` 在所列本地路径未观察到材料，并非证明所有远端渠道“全球不存在”外部响应。审查时 HEAD 仍为 `b2c04d...01b5d`，但 status 行数已从 scan 的 382 变为 384；下次 recheck 前必须重新取得一致的 T0/dirty snapshot。

### 01 external-input contract — PASS（当前收集合同，不是关闭记录）

- JSON 有 26 个唯一 ID，按 EHP-01/02/03/04 分组为 7/11/6/2；26 条均为 `typed_absent`，所有 `authoritative_channel` 的 owner/endpoint/transport/authentication/ack 均为 `typed_absent`。
- README 明确 owner 是 R2/R3 归档角色，`external; currently typed_absence` 不是已确认人员；没有凭上下文、证书库或本地环境推断 endpoint/credential/signature。故 owner/channel 没有被伪造为已存在。
- 原子顺序 `EHP-01,EHP-02,EHP-03,EHP-04`、`accepted_all|rejected_all`、精确 raw bytes/hash、packet/set/reviewer preimage、fresh identity tuple、G1/G2/G3 变化后重建下游 identity，以及缺失时 `terminal_deferred` 均保留。它没有把 local pass 提升为 authority，也没有改变 R01–R10。

### 02 integration contract — FAIL（两个 P1）

#### [P1-001] file-hash manifest 已过期，不能作为当前冻结依据

`02-integration-contract/file-hash-manifest.json:17-22` 列出 15 个文件；独立 SHA-256/byte check 在 `raw/hash_check.raw.json` 中记录为 12 match、3 mismatch：

| 文件 | manifest | 当前实际 |
|---|---:|---:|
| `tools/up1_external_closure_r4/authoritative_intake/intake.py` | 27,616 / `d6cb...04fe8b` | 30,648 / `d803...182280` |
| `tools/up1_external_closure_r4/g2_mapping/validator.py` | 22,961 / `688d...a9591` | 24,510 / `6907...e26d00` |
| `tools/up1_external_closure_r4/trust_chain/verifier.py` | 28,757 / `e7f6...055e6c` | 28,886 / `76a8...eeefb2` |

这不是 external authority 被伪造的证据，但它破坏了“当前输入/实现快照可重放”的 hash 可信度；若继续用旧 manifest，G2/trust/intake 的实际字节可能与 contract 所审字节不同。应在工作树稳定后重新捕获所有 listed files 的 bytes+SHA-256，并把旧结果作为 raw 保留；在此之前不得进入 G1/G2/G3 recheck 或宣称 implementation acceptance。

#### [P1-002] `EXTERNAL_ISSUED` seam 与 G8 外部门槛互相不可达

`02-integration-contract/interface-matrix.md:12` 明确写 `EXTERNAL_ISSUED` is rejected；同一行的 seam 是未来 integration 必须调用的 `source_axis_binding.validate_bundle`。但 `integration-acceptance-gates.md:16-17` 的 G8/G9 又要求四轴/G2 为 candidate-bound、external-authority-backed，并据此才有 recheck eligibility。当前只读代码摘录 `raw/source_axis_excerpt.raw.txt:10-12` 证实该状态在实现中返回 `external_material_not_supported`。

因此，如果不改变 seam 语义或增加一个明确的外部-verification seam，真正到达的 externally issued 四轴材料会在 row 2 被拒绝，无法形成 G8 所需的 externally verified aggregate；而 typed absence/local TEST_ONLY 又不能绕过 G8。应由合同维护者明确：外部材料如何进入、哪个模块验证其 authority、何时从 raw `EXTERNAL_ISSUED` 转成未来允许的 `externally_verified`，并补充一致的 negative/positive acceptance evidence。修复前保持 `T1_go=false`、`T2_go=false`。

## P2 观察项

1. **P2-001（措辞范围）**：00 summary 的“no fresh external input”建议改成“no fresh external material observed in checked locations at timestamp”；这样与 `network_accessed=false` 和无已知 channel 的事实边界一致。状态仍可安全保持 `typed_absent`。
2. **P2-002（失败分类）**：`failure-taxonomy.md:14-15` 在 `AUTHORITY_UNVERIFIED` 中把 `invalid/unpinned trust chain` 归到 `terminal_deferred`，而 `TRUST_TIME_REVOCATION` 对 bad chain/contradiction 又要求 `fail_closed`。虽有“contradiction dominates absence”的总规则（:26-28）可部分消歧，仍应把“缺失/不可用”与“已验证冲突/无效”写成互斥分类，避免实现按表面顺序降级 hard failure。

## 保留的边界结论

- 00/01 没有给出具体 external owner、endpoint、credential、signature 或 authority；generic role 名称来自归档矩阵并被显式标成 typed absence。
- 02 README 的 `T0 snapshot -> external-input recheck -> T1 -> T2` 顺序、all-or-reject、CAS/raw receipt、lock fields 和“local accepted_all 不是 authority”均保持；本审查没有发现绕过 39-node DAG、R01–R10、no-new-AD 或 no-S3-rerun 的路径。
- 本审查没有把本地 Python/Julia、系统 trust store、独立测试、屏幕/代理结果或 stale manifest 提升为 external evidence。

## 结论

在 P1-001 hash freeze 和 P1-002 state/seam contradiction 关闭并重审前，合同只能作为 preparation/documentation，不能作为 T0 recheck、T1/T2、publication、formal credit 或 parent-goal closure 的依据。
