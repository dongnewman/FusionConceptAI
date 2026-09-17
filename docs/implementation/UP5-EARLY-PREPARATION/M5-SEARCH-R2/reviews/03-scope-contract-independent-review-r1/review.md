# Independent review R1 — M5-SEARCH-R2 repair R2

## 判定

`NO-GO_FOR_IMPLEMENTATION / NO-GO_FOR_EXECUTION`。

本轮是独立只读合同/schema/provenance 复核。仅解析 13 个 JSON 文件、对
manifest/schema 做轻量校验、运行负向向量和 SHA-256/byte-length 重算；没有
运行 Julia、search、solver、provider、mesh、物理或性能过程，没有改动源码、
tests、registry、既有 review 或 repair 包。唯一新增路径是本 review 目录。

R2 修复包当前状态仍必须是：

`not_executed + terminal_deferred + screen_only + no_publish + formal_credit=none`。

`implementation_authorized=no`，`execution_authorized=no`。即使合同文字和
部分 schema 已补强，也没有 fixture、authority receipt、entrypoint/oracle/
checker/environment 或 owner-frozen M5-C gate；fixture/authority/M5-C gate
保持 `typed_absent`，formal credit 保持 `none`。

## 复核结果矩阵

| finding | 机器闭合结论 | 证据/负向向量 |
|---|---|---|
| P1-01 authority metadata | **NO — 部分修复** | `authority_item_schema.json` 已对 `typed_absent` 的元数据 null 做条件约束，当前 manifest 的 8 个 authority item 也诚实为 typed_absent/null；但 `input_closure_schema.json` 没有约束 closure=`typed_absent` 时四个子 item 必须全部 typed_absent/null。负向向量“typed_absent closure + authoritative children”仍 schema-valid。未来 authoritative 字节/hash/receipt 的重算和一致 join 仍只在 prose/checker 中。 |
| P1-02 content/operational receipt 分层 | **NO — 关键 digest/join 仍不闭合** | 两层 schema 都关闭了已知额外字段，但 `content_receipt_schema.json` 不表达 `content_receipt_id = sha256(canonical content bytes)`、顶层/嵌套 hash 的相等关系或 raw byte closure；`operational_envelope_schema.json` 不表达 content ID/hash、raw hash/byte 与实际文件的重算关系。构造全 0 digest 的 content receipt 仍 schema-valid。 |
| P1-03 M5-C accepted gate identity | **NO — 形状改善，身份关系未闭合** | accepted 分支现在要求字符串/hash 形状，当前 manifest 仍是 typed_absent；但 schema 无法约束 gate canonical bytes 与 `gate_receipt_hash` 相等，也无法约束 source/fixture/grammar/caps/config 与 R2 closure 相等。构造 owner/reviewer/accepted_at/全 64-hex 伪 digest 的 accepted gate 仍 schema-valid。 |
| P1-04 budget event/ledger | **NO — 算术、fold、stage/counter 关系未闭合** | `budget_event_schema.json` 只把 increment/stop 的 delta 限为 1/0，不约束 `after=before+delta`、`remaining=limit-after`、`after<=limit`；ledger 也不约束 event fold、caps、scope/seed、stage-counter 合法组合。`before=0, delta=1, after=99, limit=32` 负向向量仍 schema-valid。 |
| P1-05 descriptor identity | **NO — 字段已进入对象，来源/相等关系未闭合** | descriptor schema 固定两轴、16 bins、label erasure 和 typed_absent cell 形态；manifest/receipt/ledger/event 都有 descriptor 字段，但没有 schema 级 descriptor hash 由 canonical input 重算、cell 与 hash/axis 的相等关系或 emitter/receipt/ledger/stop 的全链路 join。当前 descriptor hash 仍 null/typed_absent，不能成为 authority。 |
| P2-01 failure precedence | **NO — 排序声明不是约束** | ordered classes 和 stage-specific `egraph_cap/qd_cap/mcts_cap/global_cap` 规则已列出，但 schema 允许重复/缺失 observation、任意 precedence rank 和不匹配的 status/resolution。将 `fail_closed` rule 的 rank 改为 7 仍 schema-valid；调用方仍可伪造 rank。 |
| P2-02 prohibited scan | **NO — registry/schema 形状改善，scan 仍不可审计闭合** | manifest 已补齐禁止 token、版本、scope 与排除 prose；但 schema 不校验 `tokens_sha256` 对 token list 的关系、不要求固定 token set/输入唯一性，也不强制 scan receipt 实际绑定输入 bytes/algorithm。将 scan 标为 pass、input_refs 置空、hash 全 0 仍 schema-valid。当前 `scan_status=not_executed` 是正确阻断，不能被当作 pass。 |
| P2-03 upstream provenance/hash | **PASS（带显式 self-hash caveat）** | R2 hash manifest 的 14 个 package entries 和 manifest 的 7 个 upstream provenance entries 均重新计算通过；路径、bytes、SHA-256 全部一致。`manifest_self_hash`/`hash_manifest_self_hash` 显式 excluded_by_policy，因此这是 package/upstream bytes integrity，不是 source authority、M5-C 或 execution proof。 |

## 关键负向验证

以下结果来自 `raw/static_review.stdout.raw`，均为 schema-level 负向控制；
`*_REJECTED=False` 表示该不合法关系仍被 schema 接受，因而不能宣称由
machine schema 真闭合：

```text
JSON_PARSE_OK=13
MANIFEST_SCHEMA_VALID=True
NEG_AUTH_TYPED_ABSENT_NONNULL_REJECTED=True
NEG_TYPED_ABSENT_CHILD_MIX_REJECTED=False
NEG_BUDGET_ARITH_REJECTED=False
NEG_FAILURE_WRONG_RANK_REJECTED=False
NEG_EMPTY_PROHIBITED_INPUT_REJECTED=False
```

另外，带格式正确但关系伪造的 accepted M5-C gate 和 digest 不匹配的 content
receipt 均被 schema 接受；这些关系只能靠尚未提供的独立 checker 复算，不能
作为 implementation readiness。

## 当前 manifest 与边界

- `manifest.json` 本身通过 `manifest_schema.json`；`implementation_authorized=false`,
  `search_executed=false`, `terminal_deferred=true`, `no_publish=true`,
  `formal_credit=none` 保持正确。
- `authority_registry.fixture/grammar/canonical_schema/source_bundle` 与四个
  interface item 全部为 `typed_absent`，null path/hash/owner/freeze；不能从本地
  source 参考推断 authority。
- `m5c_gate.status=typed_absent`, `authority_status=typed_absent`，没有 accepted
  gate；历史 M5-C、supervisor exit 或文档存在均不能替代 gate。
- descriptor 仅允许 synthetic occupancy bookkeeping；不能提升为 behavior、
  capability、physical、engineering、provider 或 formal evidence。
- 仅保留 `screen_only` claim ceiling；不得命名为 campaign/winner/capability
  increment、B00/B04、UP5 acceptance、L4 或 R01-R10 evidence。

## 授权裁决

| action | 本轮结论 |
|---|---|
| 只读 schema/manifest/provenance/hash 审查 | **允许，已完成** |
| docs/schema repair | **不自动授权；P1/P2 仍需修复并重审** |
| 创建 fixture、source、tests、checker、registry 或接线 | **不授权** |
| implementation | **no** |
| search/Julia/solver/provider/mesh/physical/performance | **no** |
| publish/formal credit | **no** |

## 后续必须闭合的最小项

1. 让 typed-absent closure、accepted/rejected gate 和 authority registry 在
   machine checker 中做互相一致的条件 join，并保存重算证据。
2. 为 content/operational digest、raw bytes、fresh replay 和 M5-C gate 加入
   可重算的 canonical-byte/hash closure；schema 形状本身不能替代 checker。
3. 对每个 budget event 执行 arithmetic/fold/scope/seed/stage-counter/cap
   检查；拒绝 overflow、under-count、skip、duplicate 和 hidden counter。
4. 对 descriptor 的 canonical input、hash、cell、tie-break 做统一 identity
   join，并由 checker 重算而不是接受调用方字段。
5. 将 failure observation→class/status/code/resolution 做成互斥固定映射，
   rank 由 checker 派生；prohibited scan 需绑定固定 token registry、输入
   bundle、algorithm 和 scan receipt。

完成后仍须由不同审查者复核新 hash/provenance；即使全部通过，也只可在
owner-frozen M5-C gate、真实 fixture/authority 和独立 checker 具备后讨论
implementation。当前绝不能执行 search 或提升 evidence credit。

## 可复核输入与输出

- repair package: `03-scope-contract-repair-r2/contract.md`, `manifest.json`,
  `schemas/*.json`, `acceptance_matrix.md`, `hash_manifest.json`
- upstream: `reviews/00-scope-contract-independent-review-r1/**`,
  `02-implementation-readiness-audit-r1/**`, `reviews/01-scope-contract-independent-review-r1/review.md`
- raw check: `raw/static_review.stdout.raw`, `raw/static_review.stderr.raw`
- process metadata: `review_receipt.json`
