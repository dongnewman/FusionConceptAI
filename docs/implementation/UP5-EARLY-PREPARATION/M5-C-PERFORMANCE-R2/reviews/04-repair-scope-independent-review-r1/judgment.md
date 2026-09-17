# M5-C Performance R2 repair-scope independent review R1 (review-04)

## 裁决

**当前不授权 M5-C 性能实现；保持 `review_pending / not_implemented`。**

本回合只读复核 `reviews/03` 的 P1-01..07、P2-01..04，并对
`04-repair-scope-contract-r2/**`、`05-implementation-readiness-audit-r1/**`、
历史 profile raw 与当前冻结 hash 做了静态核对。没有启动 Julia、M5-C probe、
DESC、S3、solver、mesh、search 或 physical 进程；没有修改被审合同、源码、
tests、oracle、probe、shared registry 或历史 raw。本 review 只写入本目录。

当前证据能够证明 04 合同方向比 03 更完整：JSON 文件可解析、优先级文字已统一、
九层 binding/negative matrix、old/current freeze、raw-row mapping 和唯一 baseline
contract 均已出现，且 `julia_process_count=0`。但多个 schema 仍只要求“有字段”，
没有把合同声称的关系、顺序、唯一性、分支优先级和 receipt 完整性变成可执行约束。
因此静态 validation 的 `pass` 不能等价于 schema/implementation readiness。

## P0：授权闸门

**P0-A — 本合同不能授权 core performance implementation，也不能授权可宣称性能
修复的 screen-only run。** 这是由 P1 schema 闭包残缺与 P2 baseline 尚未 capture
共同形成的 release gate：实现者仍可生成通过 JSON 解析、但不满足合同语义的
receipt；而性能比较对象 `M5C-R2-FROZEN-BASELINE-V2` 仍明确为
`contract_only_not_captured`、`source_run_id=null`。不得把静态检查 exit 0、文档、
历史 cold hash 或 `not_measured` 昇格为性能通过。

## 对 reviews/03 P1-01..07 的逐项复核

| ID | review-03 结论复核 | 当前独立证据 | 裁决 |
|---|---|---|---|
| P1-01 | 追加式 evidence-run、owner/path/UTC/run/overwrite 已补入合同与 manifest schema。 | 实际 manifest 有 `artifacts` 与 `frozen_inputs`，但 `manifest_schema.json` 的 required 不含 `frozen_inputs`，也没有路径唯一性、write-root containment 或冻结输入集合闭包；只要求 `artifacts.minItems=1`。 | **未闭合（P1）**：实际 manifest 目前自洽，但机器 schema 可接受缺少全部 frozen inputs 的 manifest。 |
| P1-02 | typed preflight、UInt128 饱和与 guard-before-canonical 已在合同/schema 中出现。 | `preflight_schema.json` 没有 `R`/limits 的完整结构，也没有 `cap` 与字段上界关系、`saturated_fields` 枚举或 `decision/reason/result_status/overflow/nonfinite` 的互斥闭包；negative matrix 也没有逐项 preflight receipt 规则。 | **部分闭合但仍阻断（P1）**：文字不能替代 defer-before-work 的可验收关系。 |
| P1-03 | 八条件、唯一 precedence 与 `fail_closed/condition_unmet/conditions_met` 已写入合同。 | envelope schema 只约束 8 个数组元素；没有固定顺序的 positional schema、`kind` 唯一性或每种 kind 的逐项控制。没有独立 evaluator/required-all-met receipt schema；矩阵只给一行泛化 envelope negative，而非八种条件的可复放行/负控闭包。 | **未闭合（P1）**：状态优先级文字正确，但 envelope 仍可乱序/重复。 |
| P1-04 | 九层 detached/wrong-link 矩阵与 `artifact===graph`/hash 关系已补入合同。 | `binding_schema.json` 的 `layers` 只要求至少 9 项，未要求九层唯一且各层字段全集；顶层也未封闭 additional properties，无法从 schema 验收每个字段/层的完整 binding。 | **未闭合（P1）**：矩阵是人工表，不足以阻断缺层、重复层或缺字段 receipt。 |
| P1-05 | budget priority 已固定为 `invalid > sealed_budget_mismatch > over_limit > input_overload > equal > omitted`，且 mismatch wins。 | `budget_schema.json` 有 priority enum，但没有 `priority_rank` 与 `budget_reason` 的映射、`budget_applied/result_status` 的分支一致性，仍可组合出语义冲突的 typed receipt。 | **部分闭合但仍阻断（P1）**：优先级常量存在，cross-field branch closure 缺失。 |
| P1-06 | M5CByteKeyV2、强制 digest collision、full-byte authority 和 hostile receipt 已写入合同。 | `collision_schema.json` 未要求 emitted ids/domain-specific outcomes、hostile PID/UTC/exit/raw/hash，也不强制 payload bytes/hash 相符或 A/B bytes 不同；`forced_digest` 亦无固定协议长度。 | **未闭合（P1）**：固定协议文字尚不能生成完整、可独立复放的 collision receipt。 |
| P1-07 | 三个 core regression 与四个 performance lane 已统一 supervisor 字段。 | supervisor schema 虽含 wall/exit/termination/timeout 字段，但不强制 `post_process_count=0`，也不约束 supervisor exit、child raw exit、termination、timeout class、status 的一致性；缺字段/关系可通过 JSON schema。 | **未闭合（P1）**：`supervisor_fields=pass` 只证明字段名存在，不证明监督门成立。 |

## 对 reviews/03 P2-01..04 的逐项复核

| ID | 当前核对 | 裁决 |
|---|---|---|
| P2-01 | `freeze_receipt.json` 已记录 10 个 current input、6 个 historical old/current provenance、bytes/hash、command/PID/UTC、pre/post Julia count，方向正确。 | `freeze_schema.json` 仅以 `minItems` 约束集合，没有精确 current path 集合、old/current probe 关系或 raw sidecar 内容约束；`raw_row_mapping_ref` 只是字符串。 | **合同/实际证据基本闭合，机器闭包未闭合（P2）**；fresh freeze 可保留，但需在授权前按固定集合复核。 |
| P2-02 | acceptance matrix 已把历史 raw 物理行映射为 `8/8/8/4/4/2/0`，并把 rewrite/saturate/query/replay/validate 无 receipt 留为 `not_measured`。 | `receipt_schema.json` 的 `stage_enum` 只是任意 unique string array；没有 stage receipt schema 强制 `raw_line_ids/observed_count/corrected_count/status`，因此无法机器阻止“0 代替 not_measured”或 stage 漂移。 | **部分闭合（P2，涉及实现放行）**。 |
| P2-03 | 唯一 baseline id、comparison fields、immutable/overwrite policy 已明确。 | `baseline_capture_contract.json` 明确 `contract_only_not_captured`，`source_run_id=null`，没有 baseline receipt/path/hash 实体。 | **合同闭合、证据未建立（P2）**；性能比较和 cache-on 等价性仍不可宣称。 |
| P2-04 | derivation-local、无 global mutable registry、escape flags 与三方 payload/canonical/validation hash 已列入合同/schema。 | `cache_schema.json` 的 entry 仅要求 immutable key 与四个 hash，缺 full key/payload/canonical/validation bytes、entry id/owner relation，`entry_count` 与 entries 长度无关系约束，entry 对象也未 `additionalProperties:false`。 | **未闭合（P2；若把 cache 作为 implementation authority 则升级为 P1）**。 |

## schemas / precedence / negative matrix 的综合判断

已经正确固定、可保留的内容：

1. 全局 aggregate precedence 的文字常量与 budget precedence 一致，且
   `malformed > foreign > duplicate > wrong_link > detached > altered > status_mismatch > evaluator_fault > contradiction > unknown > not_applicable > absent > unmet > met` 的顺序没有发现漂移。
2. 九层 binding matrix、collision protocol 名称 `M5CTestDigestV1`、supervisor
   字段名、fresh freeze 的 old/current 分离和唯一 baseline id 已出现。
3. 历史 raw 行号的物理内容支持 include/upstream/warm=`8/8/8`、catalog/RHS=`4/4`、
   cold source=`2`，rewrite-set=`0` 只能表示
   `not_measured_timeout_before_receipt`；不得复用旧 `5/5/5/3/3`。

仍必须修复的 machine-acceptance 缺口：

1. 为 manifest/freeze 添加固定 path-set、唯一性、scope containment 和 frozen-input
   required closure；为 stage 添加专门 receipt schema。
2. 为 envelope/binding 添加 positional/unique layer、expected field set、
   evaluator aggregate 与 artifact/hash relation 的 typed closure。
3. 为 preflight/budget/collision/supervisor/cache 添加 cross-field `allOf` 或等价
   独立 validator；不能只靠 `required`、`enum` 和静态 validation 文本。
4. negative matrix 需要可复放 raw/receipt 字段，而不是只有一张人工表；尤其八种
   condition kind、collision emitted ids、hostile supervisor 和 cache entry bytes。

## 与 05 readiness 的 scope 边界及授权建议

05 报告的判断 `implementation_ready_for_adapter_only / core-performance-scope-blocked / screen_only` 在架构边界上成立：当前四个 owner 文件可以承载 preflight、catalog/envelope receipt、derivation-local cache/key 的 adapter sidecar、负控测试和 evidence orchestration；但无法仅靠它们消除 `TypedASTProgramCanonical.jl` 的 factorial canonicalization、CEG saturation 的重复 canonical/O(M²) 扫描或 core proposal/member/visited key。那些工作需要显式新增 core seam 并 fresh re-scope/freeze。

因此本 review 的授权结论为：

- **当前授权：否。** 在上述 P1 schema/receipt closure 与 fresh baseline capture 完成并经独立复核前，不授权任何会修改四个 owner 文件、产生 implementation receipt 或运行 bounded Julia smoke 的回合。
- **条件性最小授权（未来另行明确 `implementation_authorized=true` 后）：** 只可做 `adapter_only_bounded_screen_only`：adapter preflight/guard、八条件 envelope/evaluator receipt、derivation-local immutable sidecar cache/key、对应正负控与 receipt 编排；只允许四个 M5-C owner 文件和追加式 `evidence-runs/<run_id>/**`，不改 core source、shared registry、M5-A/B、baseline 或历史 raw。
- **条件性实现的 claim ceiling：** `manufactured_conditional_egraph/screen_only`、`synthetic_egraph_equality/screen_only`；所有 timeout/program exception/human interruption/缺 receipt 保持 `terminal_deferred`/`not_measured`，不得写成性能改善。
- **明确不授权：** core performance repair、factorial/O(M²) 消除、core key replacement、cache-on 性能比较、UP5/B00/B04/L4/R01-R10、provider/physical/engineering/search/formal credit。若要做这些，必须先把四个 core 文件加入新 owner seam，重新 freeze，并在唯一 baseline capture 后另审。

本 review 不关闭 frozen parent goal。
