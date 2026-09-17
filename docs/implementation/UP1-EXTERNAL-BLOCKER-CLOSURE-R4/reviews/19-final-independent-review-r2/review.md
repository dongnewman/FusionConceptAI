# UP1 R4 final independent adversarial review R2

审查时间：2026-09-17（Windows；离线、轻量抽样）。本 review 只写入本目录；未修改 `tools/`、`test/` 或历史证据。复核范围限定为 R1 指出的两个 P1、16/18 修复证据、当前代码、02 合同、no-publish 边界、26/26 外部缺失、AD/S3 控制，以及用户指定的 Windows reparse 与 R22 direct-wire P2。

## 分开裁决

### Software scope

**`PASS_LIMITED / ACCEPT_FOR_LOCAL_INTEGRATION`。** R1 的两个软件 P1 在当前冻结实现中已得到针对性修复，并由 18/16 证据及本次轻量抽样复核：

- **R1 P1-001（跨 stage 完整 binding tuple 冲突）已关闭。** `orchestrator.py` 现在递归收集 request 与所有 stage 的同名/别名 binding 观察，不再 first-value-wins；冲突字段置 `None`，聚合返回 `fail_closed`、`rejected_all`、`BINDING_CONFLICT`，并保留原始 stage receipts/hashes。18 报告记录两次完整 integration 运行各 33 passed；本次冲突探针也得到同样结果。
- **R1 P1-002（environment lexical reparse/TOCTOU）已关闭为代码/受限运行态。** `collector.py` 先对 lexical components 做 `lstat`/reparse 检查，再 `normpath`/`resolve`；`lstat` 异常 typed fail-closed；哈希前后检查 file identity、size、mtime。16 报告的两次 repair retest 与本次独立脚本均通过 static 顺序、异常 fail-closed、root escape、identity/size/mtime 变更拒绝。

这两个 closure 仍是本地软件行为证据，不是外部 authority、可复现环境闭包或 formal gate 通过。

### Formal / external scope

**`BLOCKED / NO CREDIT`。** 00 扫描仍是冻结离线位置的 **26/26 `typed_absent`**、`usable_count=0`、无 fresh external delta；其结论是 `terminal_deferred -> no_publish`，`new_ad=false`、`s3_rerun=false`。本次未执行网络、T0、S3、Julia/DESC、solver 或 runtime。R4 不能产生 `externally_verified`、T0/T1/T2、formal/authority credit，也不能改变 parent goal 或 R01–R10。

## Findings

### P0

无。

### P1

无当前软件 P1。R1 的 P1-001/P1-002 分别由 18/16 修复证据和当前源代码闭合；没有把受限本地测试升级成 authority 或 formal closure。

### P2

#### P2-001 — Windows reparse runtime remains `test_scope_deferred`

当前 Windows 主机不能创建 symlink/reparse fixture；16 报告、本次独立 repair 脚本都明确保留 `test_scope_deferred`。这不是通过，也不能把 lexical static 检查、hardlink/普通文件结果表述为 Windows junction/symlink/reparse 的运行态证明。后续需在允许创建相关 reparse point 的 Windows 环境补一条独立 raw/exit/hash 证据。

#### P2-002 — R22 direct-wire acceptance remains incomplete

既有 predicate 证据明确：R22 使用 clean EHP-04 semantic payload；完整 wire envelope 因 quarantine raw digest 自引用问题未被完整接受。当前记录仍是 `_check_ehp04 -> terminal_deferred`、无 failure code；9/9 dispatch trap 只能证明生产 dispatch 路由，不能证明完整 external-wire acceptance。保持 `P2/test_scope_deferred`，不得升级为 P1 或软件 blocker。

## Evidence matrix

| 项目 | 当前/既有证据 | 裁决 |
|---|---|---|
| 跨 stage tuple | 18 两次 33/33；本次 33 passed；冲突探针 `fail_closed/rejected_all` 且冲突字段 unset | P1 closed；software pass-limited |
| lexical reparse / TOCTOU | 16 两次 `pass_limited`；当前 collector hash `ce6450...`; lexical-before-resolve、异常 fail-closed、三类 identity mutation 均有证据 | P1 closed；Windows reparse runtime 为 P2 |
| no-publish / lock | 当前冲突与空请求均 `no_publish=true`, `formal_credit=none`, `authority_credit=false`; T0/S3/network/runtime 全 false | 保持锁定 |
| external delta | 00 inventory/manifest：26/26 typed_absent，0 usable，no fresh delta | formal blocked；no AD/S3 |
| R22 | predicate review 与 06 证据保留 clean semantic harness/自引用 wire 限制 | P2/test_scope_deferred |
| intake smoke | 本次 `12 passed, 2 skipped`；仅本地合同/fixture | 不授 authority |

## Sample commands and boundary

```text
python -B -m pytest test/up1_external_closure_r4/integration -q
  33 passed in 0.26s
python -B test/up1_external_closure_r4/environment_closure/test_environment_closure_repair_independent.py
  exit 0; status=pass_limited; reparse=test_scope_deferred
python -B -m pytest test/up1_external_closure_r4/authoritative_intake/test_intake_contract.py -q
  12 passed, 2 skipped in 0.21s
```

Raw stdout 与 source SHA-256 sidecar 在本目录 `raw/`。16/18 的既有 raw、run manifest 与报告保持不变，未被本审查重写。最终结论严格分层：**软件：本地 `PASS_LIMITED`；formal/external：`BLOCKED / NO CREDIT`；P0=0，P1=0，P2=2。**
