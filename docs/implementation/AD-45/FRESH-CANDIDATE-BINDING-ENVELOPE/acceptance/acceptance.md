# AD45 A acceptance — FreshCandidateBindingEnvelopeV1

日期：2026-09-15  
决策：`accepted_limited`  
验收：`accepted=true`  
范围：`software_common_qualified_ref_binding_handle_and_negative_control_receipts_only`

本记录归档 root 架构裁决。它只接受 AD45 A 单的软件 common `QualifiedRefV1/v5`
绑定句柄、G1/G2 public contract 精确绑定和五项 machine-level negative-control
receipt。该句柄只用于后续同一候选 join 的临时句柄，不能作为最终 candidate identity、
declaration authority、source authority、工程结果或物理对象 hash。

## 冻结产品

两件产品未被本 acceptance 改写，冻结值为：

- `fresh_candidate_binding_envelope_v1.json`：9612 bytes，SHA-256
  `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`。
- `envelope_receipt.json`：5776 bytes，SHA-256
  `adf9caefb31398c4cf4fd04dc443fb8f409d7485e1ee04f125a28e3b427a9b64`。

common ref 仍为 `QualifiedRefV1/v5`，namespace、UUID、nonce 与 R1 修复前完全一致。
G1/G2 public refs 各自保持 `GenomeContractRef`；G2 不 alias 为
`QualifiedRefV1`。candidate identity/hash、declaration hash 均未创建。

## 独立复核依据

R1 结论为 `changes_requested`，指出五份 raw 的 artifact hash 截短、per-control
机器字段缺失及 clock result token 不精确。R1 报告和 raw sidecars 保持
append-only，不被覆盖。

修复后的不同 Luna R2 结论为 `pass_limited`，直接核验 59/59，PID `48072`，
Python 3.13.5，exit `0`。R2 确认五份 `_r2` raw 均含 canonical input SHA、namespace、
实际 UUID/nonce、allocator/CAS 字段、trusted monotonic time、exact result token、
failure semantics、no-publish 及可重算 artifact hash；五份 attempt1 raw 仍保留。

五项结果严格为：collision、replay/nonce reuse、CAS loser 和 AD42 seed misuse 为
`FailedFreshCandidateBindingEnvelopeV1` + `fail_closed`；wall-clock rollback/future/
timezone/untrusted timestamp 为 `AbsentFreshCandidateBindingEnvelopeV1` +
`terminal_deferred`。所有 `published_candidate_ref=false`。

## 本次 status sync

本次归档只新增本目录的 acceptance 产品和 `status_sync_r1/raw/` 原始核验收据。
最终 status sync 覆盖 JSON canonical/hash/path/control、common ref continuity、
五项 final raw、R1 attempt1 保留、39-task DAG 和 scoped `git diff --check`。
原始 stdout/stderr 位于 `status_sync_r1/raw/`；manifest 自身 hash 不参与自身闭环。

本次 status sync 使用 Python 3.13.5；PID、UTC、exit `0` 及 direct
JSON/hash/path/control `10/10` 均记录在 `status_sync_r1/raw/`。计划校验 exit `0`，31 markdown、497 relative
links、39 tasks、DAG acyclic；scoped `git diff --check` exit `0`。这些 raw 均位于
`status_sync_r1/raw/`，其中 stderr 和 diff streams 为零字节并保留 SHA-256。

## 信用边界与后续门

本 acceptance 不派发或接受 B-G1/B-G2 candidate-bound provenance axes；它们仍等待
W3-A、独立 source/identity inputs 和显式 G2 mapping。present、T0、T1、T2、provider、
mesh、solver、engineering、physical、search、R01–R10 与 L4 credible count 仍分别为
false/0。文档、测试、DAG 和退出码只证明软件合同与工程记录闭合，不能替代工程或物理证据。

本 acceptance 不修改 core、`task_manifest.json`、source、test、fixture、两件冻结产品、
R1/R2 reports 或其 raw；五项 old attempts 和 final `_r2` raw 均 append-only 保留。
