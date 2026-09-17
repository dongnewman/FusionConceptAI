# M5 inverse-feedback R2 scope-contract repair independent review R1

## 判定

结论：`fail_limited`，`changes_requested`；不授权 `screen_only` implementation lane。

本次只读审计确认五个 contract JSON 可解析并通过 Draft 2020-12 `check_schema`，目标包声明的 read-only 输入和 six fresh source/test/oracle hashes 均与当前磁盘字节匹配；未调用 Julia、DESC、S3、mesh、solver、provider、hardware 或网络。该结果只证明静态形状和哈希收据，不能把当前 M5/M5-A 变成已 re-freeze、已 replay 或已 accepted。

claim ceiling 仍为 `manufactured_inverse_feedback/screen_only`，`formal_credit=none`。本审查不授予 UP4、UP4-01/02/03/04、B07A/B、B08、provider、solver、工程、物理、candidate 或 R01–R10 信用。

## 对照口径

`docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md:19` 要求每个 Genome contract ref 至少有 `uri`、`version`、`schema_hash`、`canonicalization_hash`、`compatibility_profile`；同一文件 `:167-172` 区分 G1/G2/G3 hash、`genome_bundle_hash`、`physical_subject_hash` 和 `solver_input_hash`。`16_execution_work_orders.md` 的 UP4-01/03 仍分别是 B07A/B07B 正式节点，`20_midterm_audit_20260916.md` 仍标记 UP4 planned，`21_next_execution_batches.md` 要求 frozen inputs、完整 raw/PID/UTC/exit/hash 和不同角色复核。

## Findings

### F7 — P1：canonical join 仍不是完整、可执行的 G1/G2/G3/parent/mission/scenario/source identity join

`canonical_bundle_schema.json:37-46,71-97` 和 `input_schema.json:30-41` 只定义 ref/schema/content/body hash 的局部对象。它们没有规范要求的 `uri`、`version`、`schema_hash`、`canonicalization_hash`、`compatibility_profile`，parent payload 只有 `ref/content_sha256/owner`（无 typed body/body hash），candidate 中的 `parent_baseline_ref`、`mission_ref`、`scenario_id` 也没有 schema 级别的 equality/foreign-key 约束。`input_schema` 同时接受一份 `canonical_bundle` 和另一份独立 `candidate_binding`，而 `output_schema:21-23` 又接受独立 receipt；任意互不一致但格式正确的 refs/digests 都可通过结构检查。`payload_sha256`/`canonical_bundle_sha256` 也没有绑定到实际 canonical bytes 的可重算字段或 checker contract。

因此 S03/test matrix 的“structural pass”不能称为“complete canonical join”；至少需要补足规范 ref 字段、parent typed body、同 bundle 的跨对象等值检查和 canonical-bytes digest checker，然后用正/负 foreign-join vectors 证明 fail-closed。

### F8 — P1：output schema 不把 fresh replay 证据和 `valid_screen` 绑定为通过门

`output_schema.json:12-14,30` 允许 `status=valid_screen` 只由 `valid=true` 约束；`replay_count` 的 minimum 为 `0`，`attempt_ids` 没有 `minItems`，`exit_codes` 没有 cardinality/order，`semantic_equal` 与 `byte_equal` 没有依赖关系，也没有要求两次 serial replay、exit 0、attempt id 唯一或与 input/environment hash 相同。`evidence` 也没有把 `valid_screen` 强制绑定为 `screen_only_fixture`、非空 raw/process refs 和 fresh-refreeze receipt。

这使得一个没有 replay 的 output 可以被标记 `valid_screen` 且通过 JSON Schema。README/acceptance 的文字要求不能替代 machine gate。应把 valid result 的最小 replay/exit/hash/authority 条件写入 schema 或等价 typed checker，并加入 zero-replay、mismatched-attempt、byte-different、nonzero-exit 负控。

### F9 — P1：external `$ref` 的解析边界未冻结，当前“可执行 schema”只被 meta-schema 检查证明

`input_schema.json:3,13` 的 `$id` 为 `https://fusionconceptai.invalid/.../input.schema.json`，其 `canonical_bundle_schema.json` 是相对 `$ref`；`output_schema.json:3,10` 对 `failure_record_schema.json` 同样如此。静态 receipt 只调用 `Draft202012Validator.check_schema`，没有 local registry、URI-to-file mapping 或 resolver test。故从本地文件加载时，`$ref` 的基 URI 会落到不可获取的 `https://fusionconceptai.invalid/...`，实际 validator 可能无法解析依赖；即使注册依赖，也没有合同声明这一注册是必需输入。

应提供本地 registry/absolute file-independent `$id` 方案和 resolver acceptance（包含依赖 schema hash），并实际 validate 一个正例和一个 closed/foreign 负例；仅 `check_schema=true` 不足以证明 checker 可执行。

### F10 — P2：feedback CAS、immutable identity 和 append-only history 仍依赖文字/未来代码

`input_schema.json:75-76` 没有约束 `feedback_deletion.expected_version == feedback_edge.version`，也没有把 edge identity、owner、candidate、source 与 deletion 绑定。`output_schema.json:27-28` 的 operation history 允许空数组、重复/跳号 sequence、`expected_version != before_version`、任意 before/after hash 和任意 edge_ref；`recorded_utc` 仅为通用 `date-time`，不强制 UTC `Z`。result identity 还遗漏 parameter/axis，无法证明删除的就是唯一 beta/interface edge。

应补 typed cross-field checker 或可执行 state-transition schema/negative controls：stale、duplicate、foreign、dynamic-insert、wrong-owner、wrong-direction、non-UTC 和 fail-atomic history 均需明确拒绝并保留 raw receipt。

### F11 — P2：fresh re-freeze 的“dependency snapshots”与 dirty closure 仍不完整

`manifest.json:40-46` 的 fresh list 只有六份 M5/M5-A source/test/oracle；没有逐项 dependency-lock/runtime/import closure 的 path+bytes+hash，也没有把 `m5a_composition` 作为独立角色冻结（input schema `upstream:44-51` 却要求它）。环境对象只放一个未绑定路径的 dependency hash。`evidence/dirty_inventory.sha256` 只有 `git-status porcelain` 的单一摘要，不是逐文件 content hash；没有 review-end status/hash 与 baseline 后新增文件的逐项比较，因而不能独立证明 S13 “only task-owned docs changed”。

应把实际依赖/加载闭包、composition 角色和 review-start/review-end dirty inventory 纳入 manifest，明确 baseline 增量比较；不得把 `status` 摘要当作完整 dirty closure。

### F12 — P2：failure taxonomy 与 records 未做跨 schema 一致性闭包

`failure_taxonomy.json:13` 的 `codes[].code`/`class` 是任意非空字符串，未引用 `failure_record_schema.json` 的 code/class enum，也未强制每个 record code 在 taxonomy 中有唯一 resolution/class。这样 taxonomy 可以声明未被 record schema 接受的 code，或同一 code 多次不同 resolution；`check_schema` 仍会通过。

应以单一 enum/`$defs` 或生成后的一致性 checker 绑定 code/class/resolution，并增加 unknown-code、resolution mismatch 负控。

## 对 R1 P1/P2 的复核状态

| R1 finding | 本次结论 |
|---|---|
| F1 canonical candidate/source join | `fail_limited`：字段增加，但规范 ref 元数据、parent body 和跨对象 equality/digest checker 仍缺 |
| F2 executable closed schemas | `fail_limited`：五 schema parse/check_schema/closed shape pass；external resolver、reduced rational 和跨 schema consistency 未证 |
| F3 current-byte drift/refreeze gate | `partial pass`：历史-only/drift gate 存在且当前六项 hash 匹配；fresh refreeze/replay/review 未执行 |
| F4 deterministic replay freeze | `fail_limited`：request 参数写出，但 output replay receipt 可零次/无 exit cardinality 通过 |
| F5 feedback history/CAS | `fail_limited`：字段存在，state transition、CAS equality、UTC/history order 未机器闭合 |
| F6 normative inputs/dirty closure | `partial pass`：00/16/20/21/task_manifest 声明 hash 匹配；dependency closure 与 baseline 增量证明不足 |

## 通过项与边界

- 五个 repair JSON parse + Draft 2020-12 `check_schema`：`pass`。
- 当前 manifest 的 read-only input hashes、fresh six source/test/oracle hashes：本审查重新计算均 `pass`；两份 source 相对 historical R1 均确认 drift。
- `review_pending` / `not_implemented` / `not_executed` / `screen_only` / `formal_credit=none` 文案：`pass`。
- 禁止 runtime：本次仅 PowerShell/Python 静态检查，PID 88936，exit 0；Julia/DESC/S3/mesh/solver/provider/hardware/network 均 `not_invoked`。
- 目标 package 的既有 repair files 未修改；本审查仅写入其独立 review-r1 目录。

## 最终裁决

保持 `review_pending`，不授权 screen_only implementation。至少 F7–F9 必须修复并由不同角色复核；F10–F12 也须关闭或显式 typed-deferred 后，才可讨论 isolated Python-oracle → typed-checker lane。即使后续 lane 成功，最高仍是 manufactured fixture screen-only；不能转移到 UP4/B07A/B07B/B08、R 或 parent 信用。

## Evidence

- Static raw: `raw/static_review.stdout.raw`, `raw/static_review.stderr.raw`
- Process receipt: `process.json`
- Review target: `docs/implementation/UP4-EARLY-PREPARATION/M5-INVERSE-FEEDBACK-R2/02-scope-contract-repair/**`
- Normative read-only inputs were the target manifest's declared 00/16/20/21/task_manifest and R1 references; their declared bytes/SHA-256 matched current files at review time.
