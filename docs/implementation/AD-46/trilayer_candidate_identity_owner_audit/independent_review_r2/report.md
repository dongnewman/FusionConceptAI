# AD-46 三层 Candidate Identity Owner 定点独立复核 R2

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high` independent reviewer  
结论：`pass_limited`  
验收：`accepted=true`  
范围：AD-46 readiness audit 的当前状态、合同和工作单边界；不生成
CandidateIdentityV1、candidate hash、binding、T0/T1/T2、provider、mesh、solver、
engineering、physics、search 或 R01–R10 证据。

## 冻结产品闭合

本 R2 逐字节核对了用户指定的三份正式产品：

- `report.md`：12198 bytes，SHA-256
  `6a4a61a99d1d398c5ba991835e9a098a7bcc8b39b2d168759e4738ce3db9810e`；
- `manifest.json`：5466 bytes，SHA-256
  `af508ca38d592b706ef2b5990434f98998bf16bf164369da802b6fc02d4d3e08`；
- `cleanup_inventory.md`：1349 bytes，SHA-256
  `99550549388ba519f8f54f8c7039199c3f5a2b4a14b7abf586989858b633bc7b`。

manifest 的自身 hash 按合同排除。产品中的 AD-46 状态为
`readiness_audit_only`、`accepted=false`，并且明确保留 R1 `changes_requested` 及其
失败历史；本复核没有修改这三份产品。

## 上游 R2/root 状态核对

AD-44 W3-A 的当前独立 R2 manifest 为 `pass_limited`、47/47，root acceptance 为
`accepted_limited`，范围仅为 current-working-tree repository-design source software
provenance。四件产品的冻结值与 acceptance 一致：G1 record/receipt 为 6550/3404
bytes，G2 record/receipt 为 6925/3596 bytes；四个 SHA-256 分别为
`0980aa741561445f2d66efbf828100b1df3afa24d177c54a2712fa2ed7ccb750`、
`3264717def0fdb1afb0ddf1213691b41a8b37d0d7f81460cb6616d5ac16e3cc2`、
`15a2479d73270fa3ef4562bc8e509404a18c61b4392d250f7f360546098eaa3e`、
`807950e896c342ddb2187b66364687d656ef0433469a72192e32c17c86b5506d`。G1/G2 source
paths 在 HEAD 中仍为 `absent_untracked`，W3-B candidate-bound products 仍不存在，
因此该接受不提供 candidate、factory、present 或物理 authority。

AD-45 A 的当前独立 R2 为 `pass_limited`、59/59，root acceptance 为
`accepted_limited`，范围仅为 software common `QualifiedRefV1` binding handle 和
negative-control receipts。冻结 envelope 为 9612 bytes、SHA-256
`17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`；receipt 为
5776 bytes、SHA-256
`adf9caefb31398c4cf4fd04dc443fb8f409d7485e1ee04f125a28e3b427a9b64`。R1 的五份短
artifact hash、per-control 字段缺失和 wall-clock union token 问题均以 append-only
历史保留，不能被重新解释为 identity evidence。当前 common ref 仍为
`QualifiedRefV1/v5`，R1 continuity 为 true，`candidate_identity_created=false`、
`candidate_identity_hash=null`、`declaration_hash=null`。

上述两个 root acceptance 的 scope 均被本 R2 正确保留为软件有限范围；计划、测试、
独立代理和退出码没有被当作物理或工程证据。

## 三项工作单与当前阻断

三项 AD-46 工作单各自恰好声明两个产品，result union 均保留 success、typed
absence/deferred、failure 三分支：

| 工作单 | 产品数 | result union | 当前状态 |
|---|---:|---|---|
| `AD46-IDENTITY-INPUT-FREEZE` | 2 | `IdentityInputFreezeV1` / `AbsentIdentityInputFreezeV1` / `FailedIdentityInputFreezeV1` | `blocked_pending_fresh_trilayer_source_and_identity_inputs` |
| `AD46-TRILAYER-JOIN` | 2 | `TrilayerJoinV1` / `AbsentTrilayerJoinV1` / `FailedTrilayerJoinV1` | `blocked_pending_identity_input_freeze` |
| `AD46-IDENTITY-MATERIALIZATION` | 2 | `CandidateIdentityV1` / `AbsentCandidateIdentityV1` / `FailedCandidateIdentityV1` | `blocked_external_identity_owner_and_trilayer_inputs` |

当前仍缺：

- fresh G1/G2/G3 source-backed declarations、factory receipts 和三层 source identity
  reviews；AD-37 当前仍将 G1/G2 source-backed baseline 标为
  `not_found_terminal_deferred`；
- 四个同候选 candidate-bound axes；AD-43 产品仍是 source-only contract，未来
  candidate binding 字段为 `typed_absent`；
- G2 `GenomeContractRef -> common QualifiedRefV1` 显式 mapping；
- G3 source-backed declaration、binding、realization/control child、axes 和
  feedback/authority provenance；AD-34 当前仍无 actual binding/feedback authority，
  T0 false；
- 同一 fresh candidate 的三层完整 join 输入及外部 identity owner 决策。

AD-45 A 的 accepted handle 可以作为未来同候选 join 输入，但不能解锁上述缺口。AD-44
W3-B 和 AD-46 六个实现产品均未创建；当前所有三个工作单全部 blocked，未因局部
G1/G2 或 common handle 缩减为两层 identity。

## Identity owner 合同复核

`QualifiedRefV1` 仅是临时 G1/G2 同候选 join/binding handle。它排除 wall clock、seed、
payload、declaration、axis、fixture、legacy、历史 receipt 和最终 candidate hash；
不能被改名为 `CandidateIdentityV1`，也不能提供 source authority 或物理对象身份。

最终 identity 必须同时绑定三份原始类型的 G1/G2/G3 `GenomeContractRef`、三层
source-backed declaration/content/bundle hashes、三层四个 candidate-bound axes、
独立 source identity/factory reviews、显式 G2 mapping，以及同一 fresh candidate 的
G3 realization/control/binding child 和 feedback/authority provenance。缺任一层或任一
child 时只能返回 typed `AbsentCandidateIdentityV1`/`terminal_deferred`，不能输出
partial present identity。

无循环顺序仍为：fresh common handle → 三层 source-backed declarations → 独立 source
identity reviews → 显式 G2 mapping → candidate-bound axes → `IdentityInputFreezeV1`
→ `TrilayerJoinV1` semantic preimage → `CandidateIdentityV1` materialization →
T0/T1/T2。semantic preimage 不得包含自身 identity hash、未来 candidate hash、自身
URI、seed、payload hash 或历史 hash。任一 source/ref/axis/mapping/child 变化都必须重建
新的 preimage 和 identity；冲突、重放、旧候选复用必须 fail closed。

## 独立运行证据

独立 JSON/hash/path/control 复核使用 Python 3.13.5，解释器
`D:/Users/Newman/anaconda3/python.exe`，PID `86072`，UTC
`2026-09-15T12:10:26.393740Z`–`2026-09-15T12:10:26.398256Z`，exit `0`，全部检查
为 true。raw stdout 为 `review/validation_stdout.json`，1109 bytes，SHA-256
`247887a8dee8d3fc07803d620f7df20cc2fe025071ee03c3ed0d88c9154a923c`；stderr 为零字节，
SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

计划 validator 子进程 PID `37660`、wrapper PID `86212`，UTC
`2026-09-15T12:09:15.878890Z`–`2026-09-15T12:09:16.358811Z`，exit `0`，结果为
31 markdown、497 relative links、39 tasks、DAG acyclic。scoped `git diff --check`
子进程 PID `81208`、wrapper PID `88048`，UTC
`2026-09-15T12:09:16.452997Z`–`2026-09-15T12:09:16.514696Z`，exit `0`，stdout/stderr
均为零字节。全部 raw sidecars 写在本独立复核目录；没有 task-owned temporary file
需要清理，也没有修改既有 dirty worktree。

本 R2 的 `pass_limited` 只接受 AD-46 当前静态合同和状态陈述闭合。它不接受任何
CandidateIdentityV1、T0/T1/T2、provider、mesh、solver、engineering、physical、
search、R01–R10 或 L4 credit；可信 L4 候选数继续为 0。
