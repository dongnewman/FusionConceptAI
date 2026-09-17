# Independent review R1 — M5-SEARCH-R2 repair package

## 判定

`NO-GO_FOR_IMPLEMENTATION / NO-GO_FOR_EXECUTION`。

本次是只读合同/schema审查；没有运行 Julia、search、solver、provider、mesh
或任何物理过程，也没有改动源码、tests、registry 或既有审查目录。repair
包的 `typed_absent` 记录是诚实的：fixture、grammar、canonical schema、四个
execution interface 和 M5-C gate 均为 `typed_absent`，路径/hash 为 `null`，并且
静态 raw 与 02 readiness audit 一致。因此当前仍是
`not_executed + terminal_deferred + screen_only + no_publish + formal_credit=none`。

但 review-00 的 P1/P2 不能全部视为已闭合。01 的合同 prose 已明显改善，且
禁止项清单补全；然而若只按随附 JSON schemas 做机器校验，仍可构造一个
“schema-valid”但 receipt、M5-C gate、预算或 descriptor identity 不可信的包。
以下 P1 必须在任何 implementation 前修复并重新独立审查。

## 复核结论矩阵

| review-00 / readiness 主题 | 本轮结论 | 证据与边界 |
|---|---|---|
| typed_absent fixture/authority | `PASS_AS_CURRENT_BLOCK` | `01.../manifest.json:15-28` 全部缺失项为 `typed_absent` 且 path/hash 为 null；raw static audit 同样记录 typed_absent。它诚实地阻止执行，但不是 authority。 |
| receipt/envelope 分层 | `P1_NOT_CLOSED` | `contract.md:36-43` 的两层设计正确；`content_receipt_schema.json:6-19` 和 `operational_envelope_schema.json:6-19` 没有把 digest、canonical bytes、字段排除和 nested raw refs 强制化。 |
| M5-C gate identity | `P1_NOT_CLOSED` | prose `contract.md:45-47` 要求 exact join；`m5c_gate_envelope_schema.json:6-19` 允许 accepted/authoritative 对所有 hash 使用 null，且没有 accepted-at 或 gate canonical-byte 关系。当前 manifest 的 typed_absent 仍是正确阻断。 |
| e-graph/QD/MCTS budget schema/ledger | `P1_NOT_CLOSED` | `budget_event_schema.json:6-13` 只定义字段形状，没有 before/after/remaining/cap 关系、seed/ledger join 或 stage-counter约束；`budget_ledger_schema.json:8-11` 也没有把 events 与 counters/caps 绑定。 |
| synthetic descriptor | `P1_NOT_CLOSED; SEMANTICS_P2` | `synthetic_descriptor_schema.json:6-19` 已给出固定两轴和非物理边界；但 `content_receipt_schema.json`、`budget_ledger_schema.json` 未要求 descriptor hash/cell，且 hash 输入、字节投影和 tie-break 没有冻结。 |
| failure precedence | `P2_NOT_CLOSED` | `failure_precedence_schema.json:6-11` 有顺序骨架，但 budget mapping 仍是二选一字符串，未编码 egraph/QD/MCTS stage-specific reason/status，也未约束 precedence rank。 |
| prohibited tokens | `PASS_WITH_SCOPE_CAVEAT` | `manifest.json:36-40` 已补上 standalone `B00/B04/UP5/UP5-01..03/R01..R10`；schema 只定义 token list/action，未定义 tokenization、版本/hash 或 claim-only scan scope。 |
| hash/manifest | `PASS_PACKAGE_INTEGRITY; P2_PROVENANCE_GAP` | 01 hash manifest 列出的 21 个 package files 的 bytes/SHA-256 全部匹配；self-hash exclusion 已明确。但它没有绑定 review-00/02 的 source hashes 或 authority closure。 |

## Findings

### [P1-01] authority metadata 的“未来 authoritative”形态不能由 schemas 表达

`contract.md:11` 要求每个 fixture、grammar、canonical schema、source
authority、interface 同时具备精确字节、SHA-256、owner、version、来源、冻结
时间和 `authority_status=authoritative`。当前 `manifest.json:15-26` 的
`typed_absent` 记录是诚实的，不能把 null 解释为 authority；这一点通过。

但 `synthetic_fixture_schema.json`、`grammar_bundle_schema.json`、
`canonical_schema_ref_schema.json` 和 `interface_item_schema.json` 没有 owner、
source/provenance 或 frozen-at 字段，并且 `additionalProperties=false`；
`source_authority_ref_schema.json` 虽有 owner，也没有冻结时间。结果是一个
未来真实 authoritative 对象无法同时满足 prose 合同和这些 schemas，除非
执行器绕过 schema 另行解释字段。请为所有 authority item 冻结统一 metadata
字段，并让 `authoritative` 状态以条件规则要求非 null path/hash/owner/source/
freeze 与相互一致的 receipt join。

### [P1-02] content receipt 与 operational envelope 仍不能由 schema 保证

`contract.md:38-43` 正确排除了 content receipt 中的 PID/UTC/attempt 等观察
字段，并要求 `content_receipt_id=sha256(canonical_content_bytes)`。但
`content_receipt_schema.json:6-19`：

- 没有 canonical content bytes 或 canonical trace digest/bytes 字段，也没有
  约束 `content_receipt_id` 与 `canonical_content_sha256` 相等；
- `candidate_prefix`、`budget_snapshot`、`trace_rows` 是 unconstrained object，
  因而不能阻止 PID/UTC/attempt 等 operational 字段藏入 content；
- authority join 只要求任意 string，不要求 64-hex、schema/version 或 closure
  的同值 join。

`operational_envelope_schema.json:6-19` 也缺少 environment/runtime hash，
stdout/stderr nested objects 没有 `additionalProperties=false` 或 SHA/路径闭包
约束。两层命名本身不是 replay proof；在独立 checker 尚不存在的当前状态下，
该缺口足以让错误 receipt 通过结构校验。修复后应要求 canonical bytes/hash
的可重算关系，并在 content schema 中明确禁止 operational keys，在 envelope
中强制 content hash、environment hash 与 raw byte closure。

### [P1-03] M5-C accepted gate 允许空 identity，不能作为执行前置条件

`contract.md:45-47` 要求 accepted gate 绑定 source/fixture/grammar/schema、
candidate scope、entrypoint/checker/environment、R2 config、threshold、raw
streams、owner/reviewer，并且 `gate_receipt_hash` 是 envelope canonical bytes
的 digest。这一意图正确；当前 `manifest.json:28` 的 typed_absent gate 也
正确地保持 blocked。

然而 `m5c_gate_envelope_schema.json:6-19` 对 status/authority 为
`accepted/authoritative` 时仍允许所有 hashes、owner、reviewer、raw hashes 和
variance policy 为 null；没有 `accepted_at`，也没有 gate receipt canonical
bytes 与 `gate_receipt_hash` 的可重算约束。于是一个未绑定 threshold、未绑定
raw evidence 的 accepted envelope 仍可能 schema-valid。必须加入条件 required
规则：只有非 null、格式正确且与同一 R2 closure/config 精确相等的字段才能
accepted；否则强制 `gate_missing_or_unbound`、`terminal_deferred`、`no_publish`。

### [P1-04] budget event/ledger 是字段清单，不是可执行 cap ledger

`contract.md:49-65` 要求逐事件加一、不可回退、`after>limit` 立即
fail-closed，并区分 egraph、QD、MCTS 和 global caps。但
`budget_event_schema.json:6-13` 不要求：

- `after=before+1`、`remaining=limit-after`、`after<=limit`；
- seed、ledger_id、config hash、counter owner 或 source/target identity；
- stage 与 counter 的合法组合（例如 egraph stage 使用 QD counter）；
- cap hit 的 stop reason、resolution 与 event ordering。

`budget_ledger_schema.json:8-11` 只要求非负 counters 和任意 events 数组，
没有要求最后 counter 等于 events fold，也没有 per-seed/global 共享 ledger
关系、root seed identity 或 config cap join。`config_sha256` 只是一个 string
pattern，不是配置 canonical bytes 的 hash。当前 package 仍不执行，这些缺口
不会导致已经发生的 overrun，但会使未来所谓“可执行 budget closure”不能由
独立 checker 从磁盘证伪。需要补充 event fold、cap join、scope/seed、共享
global ledger 和 stage-specific stop schema，并拒绝任何 overflow/under-count。

### [P1-05] descriptor 已定义外观，但没有进入 receipt/ledger identity

`synthetic_descriptor_schema.json:6-19` 是本次最有效的修补：固定两轴、单位、
范围、16 bins、modulo normalization 和“occupancy bookkeeping only”边界，
足以避免把它直接叫作物理行为。但 `contract.md:83-85` 还要求
`descriptor_hash` 进入 emitter config、content receipt 和 ledger；相应 schema
并未做到：`content_receipt_schema.json` 没有 descriptor_hash/cell 字段，
`budget_ledger_schema.json` 也没有 descriptor join。descriptor hash 的输入
canonical bytes、prefix byte 的索引/投影规则、typed-node-count 的来源和
tie-break 亦未冻结。没有这些 join，archive occupancy 可以被换 descriptor
或改 cell 解释而不改变 receipt schema。必须把 descriptor schema/hash/cell
绑定到 emitter config、content receipt、每个 ledger stop/entry，以及明确
canonical derivation 和 replacement tie-break。

## [P2-01] failure precedence 仍有不可接受的泛化映射

`contract.md:55-81` 的优先级表比 review-00 清楚，且正确把 authority/identity
失败置于 budget 和 numerical 之前。但 `failure_precedence_schema.json:6-11`
仍存在三处歧义：

1. `budget_exhausted` 的 mapping 是
   `saturation_incomplete_or_terminal_deferred`，允许两个结论，没有分别列出
   egraph、QD、MCTS、global-prefix、screen 和 receipt cap；
2. `precedence_rank` 是任意 1..7 的整数，没有与 `ordered_classes` 的 index
   关系；`reason` 在 `budget_ledger_schema.json` 中也是任意 string；
3. `program_exception`、checker fault、absent child、`unknown` 和各类
   interruption 没有一一映射到 status/failure code，虽然 prose 声明它们要
   分离。

应把 stage、observation、status、failure_code、resolution 做成互斥映射，
并让 checker 计算 precedence rank，而不是接受调用方提供的任意 rank。

### [P2-02] prohibited token 清单已补齐，但其机器语义尚未可审计

`manifest.json:37` 已经包含 review-00 要求的 standalone `B00`、`B04`、
`UP5`、`UP5-01..03` 和 `R01..R10`，这部分通过。`prohibited_tokens_schema.json`
只规定了 token 数组和一个含糊的
`case_insensitive_exact_token_or_claim_boundary`，没有 tokenization/word
boundary 定义、清单版本/hash、扫描对象闭包或扫描 receipt。合同自身和本审查
文字会描述这些禁止项，因此 checker 必须明确“只扫描 execution claim/
publication fields”，不能把说明性 review prose 当成执行 claim；同时应保存
扫描输入 hash 和结果，避免把缺少 scan artifact 当成 PASS。

### [P2-03] repair hash manifest 完整覆盖 package，但未闭合上游 provenance

我重新计算了 `01.../hash_manifest.json` 中 21 个条目的文件长度和 SHA-256，
全部匹配；manifest self-hash 以 `excluded_by_policy` 明确记录，属于透明的
非循环设计。这个结果只证明 repair package 的字节完整性，不能证明 00
contract、02 readiness 或 source API 仍是被审查的版本。

01 package 没有列出 review-00 的 report/manifest/input hashes，也没有列出
02 audit report/source hashes 作为 source-input joins；因此该 review 的
“reviewed upstream” provenance 仍依赖路径名和人工叙述。请在下一版 review
receipt 中记录这些上游 SHA，并把 contract/schema/manifest/receipt 的 hash
覆盖范围写清楚；不要把 package hash 当成 source authority、M5-C evidence
或 execution proof。

## Readiness audit 的处理

02 readiness audit 是 repair 前的 source/API snapshot。它关于当前 checkout
没有 R2 engine、QD archive、MCTS DAG、独立 checker、M5-C join 的判断仍然
成立；01 只添加了未被 source include、未执行的合同和 schemas，不应被解释为
implementation。02 中“没有 public descriptor schema”等句子描述 source
checkout 的缺口，不能被 01 的文档 schema 反向改写成已实现能力。

## 授权边界与 required disposition

| 动作 | 本审查授权 |
|---|---|
| 只读审查、hash/manifest 重算 | `允许` |
| 新一轮 docs/schema structural repair（仅在显式 owner 批准后） | `不自动授权；当前包先修 P1` |
| 创建 `src/UP5` implementation、独立 checker、fixtures 或 tests | `不授权` |
| 接线 include/export、修改 registry/source/tests | `不授权` |
| 任何 search、Julia、provider、mesh、solver、performance 或 publish | `不授权` |

因此本轮没有任何 implementation authorization，structural preparation 也
只保留为后续显式批准的 docs/schema repair 选项。修复 P1 后必须由不同审查者
重新检查 hash joins、schema conditionality、receipt replay、budget fold、
descriptor identity、failure mapping 和禁止项 scan；在那之前保持：

`NO-GO_FOR_IMPLEMENTATION / NO-GO_FOR_EXECUTION`。

## 可复核输入与静态检查

- repair contract: `01-scope-contract-repair-r1/contract.md`
- repair manifest/schemas: `01-scope-contract-repair-r1/manifest.json` and `schemas/*.json`
- repair hash manifest: `01-scope-contract-repair-r1/hash_manifest.json`
- readiness snapshot: `02-implementation-readiness-audit-r1/report.md` and `source_hashes.json`
- review-00 baseline: `reviews/00-scope-contract-independent-review-r1/review.md`

本 review 只进行了 JSON parse、manifest/path 检查和 SHA-256/byte-length 重算；
没有任何 runtime/search execution。
