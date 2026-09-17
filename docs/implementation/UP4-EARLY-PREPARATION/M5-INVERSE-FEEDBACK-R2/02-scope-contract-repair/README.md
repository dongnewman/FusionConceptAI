# M5 inverse-feedback R2 scope-contract repair (additive)

状态保持：`review_pending` / `not_implemented` / `not_executed` / `screen_only` / `formal_credit=none`。

本包只修复 `reviews/01-scope-contract-independent-review-r1` 的 F1–F6 合同缺口；它不修改 `01-scope-contract/**`、生产源码、测试源码或任何共享 registry/task graph。没有调用 Julia、DESC、S3、mesh、solver、provider、hardware 或网络。

## 修复边界

* F1/P1：`canonical_bundle_schema.json` 冻结完整 candidate/source/parent-baseline/mission/scenario body 与 digest；request 和 result 的 binding receipt 逐项携带 G1/G2/G3、parent、mission、scenario、source schema/content/owner/provenance，以及 `manufactured_screen_only_nonphysical` 适用域。不能用 family label 或孤立 program hash 代替 join。
* F2/P1：`input_schema.json`、`output_schema.json`、`failure_record_schema.json`、`failure_taxonomy.json` 是 Draft 2020-12 可执行、closed (`additionalProperties=false`) schema；字段 type、enum、exact-rational 编码、数组顺序、unknown-field policy 和 status transition 均由 schema 约束。
* F3/P1：`freeze_gate` 固定 `historical_only`、当前 drift/authority、00-gap-audit digest 和“所有 M5/M5-A source/test/oracle/dependency fresh re-freeze → isolated replay → different-role review”前置条件。历史 R1 pass 不绑定当前字节。
* F4/P1：`replay` 固定 JCS/UTF-8/LF、Unicode codepoint 字段排序、reduced `a/b` rational、C locale、UTC、环境 fingerprint、seed `[0,1,2]`、oracle→checker 顺序、两次 serial replay 上限和 attempt identity；任何输入/代码/oracle/依赖/环境变更都要求新 freeze。
* F5/P2：feedback edge 现在是闭合对象，含 immutable identity、owner、axis/units/direction/effect scope、CAS version 和只允许 `delete_beta_or_interface_feedback` 的 append-only operation history；result 逐项保存 before/after hash、actor、UTC、direction、版本，stale/duplicate/foreign/dynamic insert 均 fail-closed。
* F6/P2：`manifest.json` 区分只读输入引用与本包写入路径，纳入 00/16/20/21/task_manifest、R1 acceptance、current M5/M5-A source/test/oracle 的 hashes；`evidence/preflight.stdout.raw`、`preflight.process.json`、`dirty_inventory.sha256` 记录 review-start HEAD/PID/UTC/exit 和 dirty baseline。S13 只比较该 baseline 之后的 additive repair path。

## Fresh re-freeze gate

本包不声称完成 re-freeze。当前 M5 与 M5-A source bytes 相对于历史 R1 receipts 漂移，故输入只能是 `authorized_not_started`，`current_authority=unknown_until_fresh_refreeze`，执行分类为 `not_executed_until_fresh_refreeze`。只有另行授权的 isolated Python-oracle → typed-checker lane、完整 raw/process/hash receipts 和不同角色复核都完成后，request 才能从 `authorized_not_started` 转为 `ready`。即使该门通过，结果最高仍为 `valid_screen`，不授予 UP4/B07/R01–R10、provider、solver、工程或物理信用。

## 验证策略

只执行静态 JSON parse/schema-shape 检查与 scope/hash audit；不运行被审源文件或任何运行时。`validation_receipt.json` 记录命令 PID、UTC、exit、raw stdout/stderr 及其 SHA-256。若未来实现填写 operation history，必须按 `sequence` 单调递增、CAS expected/before version 一致，且每一项的 canonical before/after bytes 可独立重算。

## 文件角色

`canonical_bundle_schema.json`、`input_schema.json`、`output_schema.json`、`failure_record_schema.json`、`failure_taxonomy.json` 是合同；`manifest.json` 是只读输入与状态收据；`test_matrix.md` 和 `acceptance.md` 是验收口径；`evidence/` 是本次静态审计的不可变 sidecar。所有结论仍是 `review_pending`，不是 implementation acceptance。
