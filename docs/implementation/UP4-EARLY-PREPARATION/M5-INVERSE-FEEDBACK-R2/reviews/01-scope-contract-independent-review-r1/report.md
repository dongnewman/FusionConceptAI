# M5 inverse-feedback R2 scope-contract independent review R1

## 判定

结论：`fail_limited`，建议 `changes_requested`。本目录的 JSON 文件可解析、产物路径确实位于 review 目标之外的 task-owned scope，且没有运行 Julia/DESC/S3/mesh/provider/solver；但 scope contract 不能以 `pass_limited` 接受，因为 candidate/source binding、可执行 typed schema、replay freeze 和当前 R1 字节边界仍有阻断性缺口。

claim ceiling 仍为 `manufactured_inverse_feedback/screen_only`，`formal_credit=none`。本审查不授予 UP4、UP4-01/02/03/04、B07A/B、B08、provider、solver、工程、物理、candidate 或 R01–R10 信用。

## 对照口径

- `docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md` 要求三 Genome/mission/bounds 的分层 hash、candidate-bound physical subject 与 solver-input identity，状态维度独立，缺能力保持 `terminal_deferred`。
- `16_execution_work_orders.md` 仍将 UP4-01→UP4-02→UP4-03→UP4-04 作为依赖链；UP4-01 使用 B07A，UP4-03 使用 B07B，不能由 manufactured slice 替代。
- `20_midterm_audit_20260916.md` 与 `21_next_execution_batches.md` 明确当前 UP4 四节点均 `planned`，并要求先冻结完整执行闭包；M5 当前源字节 drift 时必须 fresh re-freeze 后才能复放。
- R1 root acceptance 的 `accepted_limited` 只覆盖历史冻结字节的 isolated manufactured exact-Rational inverse/feedback control，ceiling 为 screen-only，未关闭任何正式 UP4/B07/R 父门。

## Findings

### F1 — P1：candidate/source binding 在输入和输出上均不可完整审计

R2 README 第 48 行把 source key 定义为 `(source_ref, source_content_sha256, source_owner, provenance_ref, source_schema)`，并要求所有 key 来自同一 canonical bundle；但 `input_schema.json` 第 16–31 行没有 `source_schema`、canonical bundle bytes/digest、candidate bundle/physical-subject hash 或 scenario hash。`output_schema.json` 第 20 行的 binding receipt 只要求 `candidate_ref/source_ref/scenario_id/input_sha256/upstream_hashes/owner_ledger/provenance_ledger`，丢失 G1/G2/G3、parent-baseline、mission、source-content/owner/provenance/schema 等 join 维度。结果即使填入任意 ref 字符串，也无法证明是同一 candidate/source bundle；这不满足 00 的 candidate-bound identity 语义。

处置：冻结 canonical bundle、candidate/source/mission/scenario 的完整 typed body 与 digest；输出 receipt 必须逐项携带三层 refs、parent/mission/scenario hash、source schema/content/owner/provenance 和明确的 screen-only/non-physical-subject 适用域。若不打算形成 candidate identity，应改称 test-context binding 而不是 candidate-bound。

### F2 — P1：所谓 typed schemas 只是描述性清单，不是可执行 schema

`input_schema.json`、`output_schema.json` 和 `failure_taxonomy.json` 都没有 JSON Schema 的 `type`、`properties`、`items`、`enum`、`additionalProperties` 或嵌套字段约束；只有字符串 `required`/`type` 标签。因而 S01 所称“字段/枚举完整”无法由该文件本身验证。另有直接不一致：README 第 24 行允许未来 input status `authorized_not_started` 或 `ready`，而 `input_schema.json` 第 3 行只有单值字符串 `authorized_not_started`，没有 enum/transition 规则。

处置：提供版本化、可执行的 request/result/failure JSON Schema 或等价 typed checker contract，明确每个字段的 JSON type、exact-rational encoding、nullability、closed enums、array ordering、unknown-field policy 与 transition；静态验收只能在 parser 实际执行后写 pass。

### F3 — P1：R1 accepted bytes 与 R2 当前 source bytes drift，但 R2 未把 fresh re-freeze 设为前置

R2 `manifest.json` 第 21 行冻结当前 M5 source 为 26,187 bytes / `477b5a41…110e59`；R1 root acceptance/repaired review 冻结的是 26,255 bytes / `f0dcf8aa…553976`，M5-A 也从 `e6262a11…1945a` 漂移到当前 `284094e7…a209`。R2 的 00-gap-audit 已明确 current authority 为 unknown、历史 pass 仅适用于旧字节，并要求先 fresh current-byte re-freeze + isolated replay；但 scope-contract README/acceptance 只写“R1 已冻结”并把当前 source hash 作为普通输入，未显式标记历史 accepted_limited 不绑定当前 bytes，也未把 00-gap-audit 的 drift receipt 纳入 input hash closure。

处置：在合同入口增加 `historical_only`/`current_not_executed` 标记，冻结并 hash 00-gap-audit、当前 M5/M5-A source/test/oracle 全部依赖；fresh re-freeze、isolated replay 和不同角色复核完成前，禁止将当前字节写成 R1 可复用输入或任何 pass-limited basis。

### F4 — P1：replay policy 的关键参数未真正冻结

README 第 63 行要求 canonical input bytes、source/code/oracle hashes、environment fingerprint、seed ledger 产生 byte-identical output；但 `input_schema.json` 第 81–96 行只冻结了 SHA-256、seed `[0,1,2]` 和 oracle→checker 顺序，`canonical_serialization`、字段排序、locale、timezone、environment_fingerprint 没有具体值或 schema。`output_schema.json` 第 49–51 行虽要求 byte equality 和 exit codes，也没有定义如何计算/绑定这些字段。该状态无法满足 00/21 对输入闭包、环境身份、fresh replay 的可重建要求。

处置：冻结 canonical serialization profile、UTF-8/行尾/数字与 rational 编码、字段排序、locale/timezone、依赖/runtime fingerprint、seed ledger 结构和 replay attempt identity；每次 replay receipt 逐项列出并 hash。

### F5 — P2：feedback edge 的 immutable/editable/history 语义没有落到 schema

README 第 50 行要求 immutable edge identity、editable state、仅允许 `delete_beta_or_interface_feedback`、追加 operation history 且可重放；但 `input_schema.json` 第 53–74 行把 `feedback_edge`/`feedback_deletion` 表示为字符串/示例值，`output_schema.json` 第 33–37 行只要求 edge identity、active/deleted response、delta、changed、units、scope，没有 operation type、CAS/version、before/after canonical bytes、actor/owner/direction 或 operation history。S05 也只验证响应数值，不能证明禁止插入/换源/换 candidate 或 fail-atomic history。

处置：将 edge 定义为闭合 typed object，冻结 operation enum、CAS/version、source owner/effect scope/units/direction、before/after hashes 与 append-only history；增加 stale/duplicate/foreign/dynamic-insert 的负控。

### F6 — P2：静态接受条件与输入引用/dirty worktree 的边界含混，且未冻结 00/20/21/task_manifest

`acceptance.md` 第 7 行说路径 confined to task-owned directory，第 18 行又要求完整 raw/process/PID/UTC/exit/hash；但 R2 `manifest.json` 的 input hashes 指向 task-owned 目录外的 R1、12/13/16、源码文件，且没有 00、20、21 或 current `task_manifest.json` 的 hash。当前 worktree 还存在大量预先 dirty/untracked 内容；R2 只写 `dirty; pre-existing changes protected`，没有 before inventory/hash 证明 S13 “only task-owned docs changed” 的时点边界。已执行 static receipt 只报告 5 个 package JSON 和一个 source hash，不能证明这些完整条件。

处置：区分“产物写入路径”与“只读输入引用路径”；把 00/16/20/21/task_manifest、R1 root acceptance 和 gap-audit 纳入 manifest；记录 review-start dirty inventory/HEAD/status hash，S13 仅比较 review 期间增量。保留所有外部输入为 read-only，不能把其路径误报为 task-owned deliverable。

## 通过项与未通过项

| 项 | 独立结果 |
|---|---|
| 目标目录内 JSON 可解析 | `pass`（7 个 JSON，包括 archive process receipts） |
| review 产物路径 confined | `pass` |
| 禁止 runtime 未调用 | `pass`；仅运行 PowerShell 静态检查，PID 29160，exit 0 |
| screen-only / no-credit 文案 | `pass`（未发现正向 `credible_within_scope`；其余命中来自禁止词/边界文案） |
| candidate/source/upstream 完整 join | `fail`（F1） |
| machine-valid typed schema | `fail`（F2） |
| current bytes bound to R1 accepted scope | `fail`（F3） |
| deterministic replay freeze | `fail`（F4） |
| feedback operation replayability | `fail`（F5） |
| 00/16/20/21/task_manifest 与 dirty diff closure | `fail_limited`（F6） |

## 最终边界

本审查建议保持 `review_pending`，直到 F1–F4 至少关闭并由不同角色复核；F5–F6 也应在任何 implementation authorization 前关闭或显式记录为 typed deferred。R1 历史 exact-Rational 结果只能作为历史 screen-only context，不能覆盖当前 source drift、真实参考/B07B、B07A 硬件/回流/电源/热/结构、UP4 依赖或 00/20/21/task_manifest 的主线门。

无 Julia/DESC/S3/mesh/provider/solver/hardware/网络运行；没有修改被审件、生产源码或测试源码。本 review 仅写入其自身目录。
