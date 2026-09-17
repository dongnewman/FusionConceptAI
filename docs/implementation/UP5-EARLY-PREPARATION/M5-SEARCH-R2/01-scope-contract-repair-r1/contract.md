# M5-SEARCH-R2 scope-contract repair R1

状态：`review_pending` / `not_executed`  
范围：`bounded_synthetic_search/screen_only`  
claim ceiling：`screen_only`；`no_publish=true`；`formal_credit=none`

本修订逐项闭合 `reviews/00-scope-contract-independent-review-r1` 的 P1-01..P1-04、P2-01..P2-03。它是合同与机器可读 schema，不是实现授权、搜索结果、性能结果或父目标关闭证明。当前回合只写本目录；不改 `00-scope-contract/**`、`reviews/**`、源码、tests、registry、历史 raw，也不执行 search/Julia/DESC/S3/solver/provider/mesh/physical。

## 1. 不可变状态与权威边界

R2 只能消费一个版本化 synthetic fixture、一个版本化 grammar bundle、一个 canonical schema、一个 source-authority receipt，以及绑定的 entrypoint/oracle/checker/environment interface。每一项必须同时有：精确字节、SHA-256、owner、版本、来源、冻结时间和 `authority_status=authoritative`。本修订中这些对象均未提供，因此 manifest 以 `typed_absent` 明确记录，hash 必须为 `null`；`typed_absent` 不是空字符串、占位内容或通过本地源码推断的 authority。

缺任一 authority join、版本、字节或 hash 时，唯一可接受结果为 `not_executed` + `terminal_deferred` + `no_publish=true`；不得以 `unknown`、缓存命中、历史 M5-C、文档存在、源码参考或 supervisor exit 替代。声明的 interface 仅描述未来接线，不代表可执行 entrypoint。

冻结的 join 是：

```text
fixture_id/version/content_sha256/source_authority_receipt_hash
grammar_id/version/content_sha256/source_authority_receipt_hash
canonical_schema_id/version/content_sha256/schema_sha256
entrypoint_id/version/path/command/interface_sha256
oracle_id/version/path/command/interface_sha256
checker_id/version/path/command/interface_sha256
environment_id/version/lock_sha256/interface_sha256
mission_hash/bounds_hash/scenario_hash/source_bundle_hash
```

任何 `typed_absent` 或 stale/mismatch 都是 `fail_closed` 的输入身份失败；只有“输入存在但没有物理/provider 权限”才可落入 provider gap。这里没有 synthetic fixture 或 grammar authority，因此不产生 candidate、trace、screen receipt 或 M5-C pass。

## 2. 未来接口合同（声明，不授权）

entrypoint 必须接收 sealed `InputClosureV1` 与 sealed `BudgetConfigV1`，输出分层 receipt；不得读取未列入 closure 的文件、时间、PID、filesystem order、thread scheduling 或 ambient environment。oracle 必须是独立进程/实现，只消费 canonical content bytes，输出 expected content digest、expected trace digest 和 typed comparison；oracle 不能复用 entrypoint 的 receipt或缓存。checker 必须独立重算 canonical bytes、所有 hashes、joins、budget ledger、failure precedence 和 prohibited-token scan；checker 的 `pass` 只表示合同结构通过，不是 search pass。

environment interface 必须冻结 OS/runtime/version/locale/encoding/PRNG implementation/CPU parallelism/project lock 和 command envelope。`environment_sha256` 不含 PID、UTC 或临时目录；缺 lock 为 `typed_absent`。未来 execution 需 `pre_process_count=post_process_count=0`（除被明确记录的单个 child）且一进程串行。

## 3. 分层 receipt 与 replay

每个 proposal/rejection/budget-stop/replay 都有两层：

1. `ContentReceiptV1`：仅 canonical content。它包括输入 joins、candidate/prefix/action/rule/emitter/seed/sequence、canonical payload、budget snapshot、typed outcome、failure code、trace rows 和 hashes；不包括 PID、UTC、attempt id、随机 UUID、路径临时部分或 exit observation。`content_receipt_id=sha256(canonical_content_bytes)`，所有数组按 canonical bytes 排序，null 显式编码。
2. `OperationalEnvelopeV1`：一次观察的 PID、UTC start/end、command、cwd、host、exit、timeout/termination、raw stdout/stderr paths+hashes、attempt/run id 及 `content_receipt_id`。它只能引用 content receipt，不能改变 content hash，也不能被用作 replay equality。

Fresh-process replay 比较 `content_receipt_id`、canonical content bytes、trace bytes 和 checker result；比较两个 operational envelopes 的配置/authority joins和 raw exit类别，但不比较 PID/UTC/attempt/run ids。任何 content 不同为 `replay_mismatch`；仅 operational 差异不构成 mismatch。未形成两份 fresh-process content receipts 时状态是 `not_executed`，不是 replay pass。

## 4. M5-C performance gate identity envelope

R2 execution 的前置条件是 `M5CGateEnvelopeV1.status=accepted`。该 envelope 必须绑定同一 `source_bundle_hash`、fixture/grammar/schema hashes、candidate scope hash、entrypoint/checker/environment hashes、R2 caps/config hash、measurement command hash、raw stdout/stderr hashes、threshold hash、variance policy、owner 和 independent reviewer。`gate_receipt_hash` 是 envelope canonical bytes 的 SHA-256；历史 M5-C 路径不能自动满足 join。缺字段、stale、foreign、failed、未独立审阅或 `typed_absent` 均为 `gate_missing_or_unbound`，强制 `terminal_deferred/no_publish`。本修订不发明阈值，不把 M5-C 历史失败变成 pass。

## 5. 可执行预算、ledger 与停止规则

所有计数使用非负整数、逐事件加一、不可回退；per-seed ledger 与 global ledger 都必须覆盖 `eclass_created`、`enode_created`、`rewrite_applied`、`trace_rows`、`qd_proposals`、`qd_cells`、`qd_members`、`mcts_roots`、`mcts_expansions`、`mcts_proposals`、`unique_prefixes`、`screen_evaluations`、`proposal_receipts`、`global_trace_rows`。每条 event 写 before/after/limit/remaining/stage/sequence，`after>limit` 立即 fail-closed，不得静默截断。

冻结 cap 仍为旧合同的有限设计：root seeds `[11,23,37,41,53,67,79,97]`；per seed rewrite 32/eclass 128/enode 512/trace 512；QD proposals 24/cells 16/members-per-cell 2；MCTS roots 4/depth 3/expansions 24/proposals 24；global unique prefixes 64/screen evaluations 64/proposal receipts 48/trace rows 4096；solver/provider/mesh/physical executions 0。它们只有在 implementation/profile authority 出现并 hash 后才可执行。

停止优先级固定为：

```text
identity/schema/authority malformed or foreign
  > contradictory input / checker fault
  > operational interruption or timeout
  > per-seed/global hard cap
  > synthetic non-finite arithmetic
  > typed applicability unmet
  > admissible completion
```

stage-specific mapping：

| stage | stop observation | required status | failure code |
|---|---|---|---|
| admit/hash | missing/foreign/stale fixture, grammar, schema, source authority, interface or env | `not_executed`, `terminal_deferred` | `typed_absent` / `identity_mismatch` / `fail_closed` |
| canonicalize | malformed/duplicate/nonfinite canonical input | `not_executed` | `schema_malformed` / `fail_closed` |
| e-graph saturation | eclass/enode/rewrite/trace cap before closure | `terminal_deferred` | `egraph_budget_exhausted` (`saturation_incomplete`) |
| QD emission | proposals/cells/members/global prefix/receipt cap | `terminal_deferred` | `qd_budget_exhausted` |
| MCTS emission | roots/depth/expansions/proposals/global cap | `terminal_deferred` | `mcts_budget_exhausted` |
| screen | nonfinite synthetic arithmetic | `screen_fail` | `numerical_fail` |
| screen | missing provider/backend/authority (not needed for pure screen) | `terminal_deferred` | `provider_match=no_match\|out_of_domain\|invalid_signature` |
| any stage | child timeout/kill/absent process | `not_executed` or `terminal_deferred` | `human_interruption` / `timeout` / `unknown` |
| any stage | typed side condition unmet | `screen_only` member rejection | `not_applicable` (zero merge) |

`program_exception` is reserved for an actual implementation/checker exception after valid sealed input; it is never a synonym for budget stop, typed unmet, missing authority, timeout or `fail_closed`. Physical/provider/engineering outcomes are outside this slice and cannot be emitted.

## 6. Synthetic descriptor (not behavior evidence)

QD uses `SyntheticDescriptorV1` only to partition deterministic synthetic screen members. It has fixed dimensions, units, normalization, bounds, bins, tie-break and derivation; the descriptor is derived from canonical typed prefix bytes and ledger counts, not from physical equations, provider data, measured behavior or capability. `descriptor_hash` is joined into emitter config, content receipt and ledger. Occupancy is an archive bookkeeping fact only; it is not a behavior descriptor, search-capability increment, candidate quality claim, originality, feasibility, L4 or B00/B04 evidence.

## 7. Machine prohibition and handoff

Downstream machine checks must reject exact tokens and case-insensitive variants of: `Julia`, `DESC`, `S3`, `solver`, `provider`, `mesh`, `physical`, `engineering`, `production_source_edit`, `test_source_edit`, `default_registry_edit`, `search_execution`, `campaign`, `winner`, `capability_increment`, `B00`, `B04`, `B00_F0-F5`, `B04_50_receipts`, `UP5`, `UP5-01`, `UP5-02`, `UP5-03`, `R01`, `R02`, `R03`, `R04`, `R05`, `R06`, `R07`, `R08`, `R09`, `R10`, `L4`, `formal_equivalence`, and `M5-C_PASS`. These are prohibited claim/operation tokens, not evidence of their occurrence.

This package is `review_pending` and `not_executed`; static raw only. No search, Julia or performance measurement was run. A future independent review must verify all schema/hash joins and that no prohibited token appears in an execution claim before any separate implementation authorization.
