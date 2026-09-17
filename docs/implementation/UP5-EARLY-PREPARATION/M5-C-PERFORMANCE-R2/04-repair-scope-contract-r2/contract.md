# M5-C Performance R2 repair-scope contract (R2)

状态固定为 `review_pending` / `not_implemented`；实现授权为 false。scope 为
`manufactured_conditional_egraph/screen_only`，claim ceiling 为
`synthetic_egraph_equality/screen_only`，`formal_credit=none`。本目录只修订合同、
schema、fresh freeze 和静态 raw，不运行 Julia/DESC/S3/solver/mesh/search/provider/physical。
`not_implemented`、`screen_only`、`formal_credit=none`、`terminal_deferred`、
`not_measured`、`program_exception`、`human_interruption`、`fail_closed` 和
`condition_unmet` 不得被包装成 pass、性能结果、工程证据或 formal credit。

## 1. 边界、owner 与追加式 evidence-run

本回合写入根目录仅为：
`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/04-repair-scope-contract-r2/**`。
不得改写 `00-static-audit/**`、`01-profile/**`、`02-repair-scope-contract/**`、
`03-repair-scope-contract-r1/**`、`reviews/**`、源码、测试、oracle、probe、shared
registry、历史 raw 或任何生产 artifact。

未来获得单独实现授权后，源码 owner 仍只有四个：

| relative_path | owner | allowed role |
|---|---|---|
| `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` | `m5c_adapter` | preflight/evaluator/binding/key/cache |
| `test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl` | `m5c_test` | positive/negative typed controls |
| `test/RuntimeV4/M4Isolated/oracles/conditional_egraph_oracle_v1.py` | `m5c_oracle` | independent reference only |
| `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl` | `m5c_probe` | probe/stage receipt only |

未来 evidence 只能追加至本目录的
`evidence-runs/<run_id>/{manifest.json,freeze_receipt.json,hash_manifest.json,receipts/<stage>.json,raw/<stage>.{stdout,stderr,combined}.raw}`。
`run_id` 必须是唯一 UTC 时间戳加序号；已经存在的 run 不得复用；`overwrites` 必须永远
为空数组；不得使用 symlink/junction、共享 registry 或可变外部引用。所有 evidence
文件都必须拥有 `owner`、`relative_path`、`creation_utc`、`source_run_id` 和
`overwrites=[]`，见 `schemas/manifest_schema.json`。

## 2. P1-02：typed preflight 与 arithmetic guard

一次 derivation 的顺序是：sealed upstream bytes/hash 校验 → 结构性 hash → 读取
`n/R/rule_count/budget/limits` → 写入 `M5CPreflightReceiptV2` → 只有
`decision=admit` 才可构造 rewrite-set、factorial/full canonical order、saturation
或 full receipt serialization。preflight 前禁止 canonical writer、`n!` 非饱和计算、
rewrite constructor、proposal/member/visited emission、partial canonical hash。
`canonical_writer_called=false` 与 `rewrite_set_constructor_called=false` 是 receipt
的强制布尔值，不是叙述性字段。

所有非负估计使用 UInt128 saturating arithmetic。`cap=min(UInt128_MAX,max(limit,1)+1)`；
每个加法/乘法先检查溢出，达到 cap 就写入 `saturated_fields` 并置 `overflow=true`。
`n!` 只允许逐项 saturating multiply。负数、NaN、Inf、缺结构性输入、无法保守估计或
任何 limit 超界都必须 `decision=defer`、`result_status=terminal_deferred`，并带
estimate/limit/input hash/budget/reason；不得发布等价 hash。

## 3. P1-03：唯一的八条件与 required closure

唯一 envelope 是 `M5CAvailableConditionEnvelopeV2`，conditions 必须恰好 8 项且按
`type, rank, domain, unit, port, owner, interface, conservation` 顺序排列；kind 不得
重复。每项必须有 `kind, ref, expected_hash, required, fact_status, fact_value,
fact_hash, evidence_ref`。envelope 本身必须有 schema/version/id/candidate/M5-A hash/
M5-B hash/catalog ref+hash/canonical bytes+sha256/producer owner。

全局唯一优先级（从高到低）为：

`malformed > foreign > duplicate > wrong_link > detached > altered > status_mismatch > evaluator_fault > contradiction > unknown > not_applicable > absent > unmet > met`。

优先级前 9 项均映射到 `fail_closed`；`unknown/not_applicable/absent/unmet` 映射到
`condition_unmet`；只有所有 `required=true` 项为 `met` 且无更高优先级异常时才是
`conditions_met`。`required_all_met` 必须等于逐项布尔归约，不能由 aggregate 反推。
`not_applicable` 不等于 `unknown`，`contradiction` 不得包装成普通 unmet；8 项各自
必须有 met、unknown、not_applicable、contradiction、foreign 的控制记录。oracle 只做
独立 reference，Julia evaluator receipt 才是 adapter authority。

## 4. P1-04：逐层 binding 与 detached/wrong-link 矩阵

每个 immutable product 必须产生 `M5CFullBindingReceiptV2`，对每个字段执行
`present + exact bytes + sha256 + owner/ref + object relation`。任何
missing/foreign/altered/duplicate/wrong_link/detached/status_mismatch 都是
`fail_closed`。`derivation.artifact` 必须与 `graph` 对象身份相同，并且
`sha256(artifact_bytes)==graph.artifact_hash`；graph 存在而 derivation 缺失必须
`graph.derivation_missing`。

矩阵按层固定为：M5-A source/program/composition；M5-B source/inverse/upstream；
owner/provenance；catalog/envelope/evaluation；rewrite/rule/checker/source program；
derivation/id/budget/profile/usage/trace/provenance/artifact；graph/id/source/members/
conditions/artifact；adapter/schema/ceiling/scope/status。每层的错误码和 receipt 字段
见 `acceptance_matrix.md` 与 `schemas/binding_schema.json`。只校验间接 source hash、
只校验 graph 非空、或只校验 catalog shape 均不合格。

## 5. P1-05：budget 分支和优先级

入口必写 `requested_budget,effective_budget,budget_applied,budget_reason,
sealed_budget_hash,result_status`。唯一优先级为 `invalid > sealed_budget_mismatch >
over_limit > input_overload > equal > omitted`；因此 sealed product 同时 budget 不同
且预计超限时，唯一结果是 `budget_mismatch`，不得改写成 deferred 或 rebuild。

| input | result_status | budget_applied |
|---|---|---|
| omitted | `no_op` | `omitted_identity_preserve` |
| equal to sealed | `no_op` | `equal_identity_preserve` |
| sealed product differs | `budget_mismatch` | `reject_sealed_mismatch` |
| explicit unsealed input overload | `rebuilt` | `rebuild_input_overload` |
| admitted input exceeds limit | `terminal_deferred` | `defer_over_limit` |
| invalid/nonfinite/negative budget | `fail_closed` | `reject_invalid` |

## 6. P1-06：immutable key、可复放 collision 与 hostile receipt

`proposal/member/visited` 共用 `M5CByteKeyV2`：
`ASCII("M5C-K2") || u16be(field_count) || repeat(u32be(byte_length)||raw_bytes)`。
字段顺序固定为 `key_domain,candidate_identity_bytes,upstream_identity_bytes,
canonical_program_bytes,condition_envelope_bytes,rule_set_bytes,budget_bytes`。
full byte key 是 authority；digest 只能索引候选桶，不能决定 equality 或 emission。
排序使用固定 bytewise comparator，不能依赖 map iteration。

collision 负控固定使用 payload A/B（相同 `key_domain`、不同 canonical bytes）和
`M5CTestDigestV1` 注入器：A/B digest 强制相同、full key 必须不同；receipt 必须写
payload bytes/hash、forced digest、bucket id、full-key compare、collision outcome、
emitted ids、proposal/member/visited domain、hostile process PID/UTC/exit/raw/hash。
同 key 异 bytes 必须 `key_collision` 并 fail-closed；同 full bytes 才允许 dedup。
该协议可由独立进程按固定 bytes 重放，不能使用随机 seed 或实现自选 payload。

## 7. P1-07：统一 supervisor receipt

三个 core regression 和四个 performance lane 使用同一个 `M5CSupervisorReceiptV2`。
每条命令串行、独立 process，必须记录 command/flags/cwd/host、supervisor PID、child
PID/parent PID、前后 Julia process count、UTC start/end/deadline、
`supervisor_wall_seconds`、`supervisor_exit_code`、child raw exit、termination、
timeout class、raw paths/bytes/SHA-256、input/output hash、status 和 receipt hash。
`termination` 枚举为 `completed|timeout_kill|human_interrupt|program_exception|external_kill|not_started`；
`timeout_class` 为 `none|within_deadline|soft_timeout|hard_timeout|unknown`。
supervisor 自身 exit 非 0、字段缺失、post Julia count 非 0、raw/hash 不匹配均为
`supervisor.receipt_incomplete`，并覆盖业务结果。

## 8. P2-01：fresh freeze

每个 run 只有一个 `M5CFreezeReceiptV2`，记录 capture command、command exit、PowerShell
PID、UTC、HEAD/branch/cwd、pre/post Julia count、当前 source/test/oracle/probe 与
所有 frozen core input 的 path/bytes/hash，以及历史 old record 的精确 path/bytes/hash。
旧 probe 是 `01-profile/manifest.json::frozen_inputs.probe_at_capture`（12812 bytes，
`F01F4800...3FB88`）；当前 probe 是 checkout 的 12817 bytes，
`7EA02E3D...56522`。旧/current 永远分开，旧 hash 不能作为 current identity。

## 9. P2-02：stage enum 与历史 raw-row receipt 映射

stage enum 仅允许 `include, upstream_first_compile_plus_build, upstream_warm_build,
prepare_condition_catalog, prepare_rhs, prepare_source_cold_hash, prepare_rewrite_set,
saturate_budget_2_4_1_2, saturate_budget_3_8_2_3, saturate_budget_4_16_3_4,
saturate_budget_8_32_4_8, query, replay, validate`。`prepare_rewrite_set_constructor`
不是合法 stage。历史 raw 的可校正映射固定为 `8/8/8/4/4/2/0`，每一项必须带 raw path
和 line id（详见 acceptance matrix）；`prepare_rewrite_set` 的 0 只能写
`not_measured_timeout_before_receipt`，没有 receipt 不能写 numeric zero。旧
`measurements.json` 的 `5/5/5/3/3` 不可复用。

## 10. P2-03：唯一 baseline capture 合同

唯一比较对象为 `M5C-R2-FROZEN-BASELINE-V2`：当前 fresh freeze 下、未修复 sealed
baseline 的 source/test/oracle/probe/core hashes、同一 candidate-bound envelope、同一
profile 和 lane budget。baseline capture 必须有 run id/path/receipt/hash，并冻结
source/program/canonical bytes/hash、envelope bytes/hash、profile/budget、graph/usage/
trace/witness/status 字段。cache-on 修复结果只能与该 baseline 比较 bytes/hash/status/
tie-break/witness 完全一致；不得提供“cache off 或 sealed baseline”的二选一。
本回合仅写合同，不宣称 baseline 已执行或已产生 performance evidence。

## 11. P2-04：cache typed schema 与 escape controls

cache 唯一类型为 `M5CCacheReceiptV2`，owner 必须是当前 `derivation_id/product_id`；
entry 必须带 immutable key/full bytes/payload bytes/hash/validation receipt。禁止 global
mutable registry、跨 derivation/product 命中、隐式 world state、可变 key、对象地址和
引用逃逸。必写 `cache_owner,cache_id,entry_count,shared_entry_ids,escape_detected,
cross_derivation_hit,alias_detected,mutation_after_seal,payload_hash,canonical_hash,
validation_hash,cache_status`。重复 derivation 必须新 cache、同 bytes/hash；跨 derivation、
alias、seal 后 mutation、clear/drop 后使用均 typed fail-closed 或 no-op。

## 12. 放行顺序与证据上限

未来授权顺序固定为 fresh freeze → source/hash recheck → schema/preflight tests → M5-C
positive/negative/oracle → core regression → prepare receipt → four budget lanes →
query/replay/validate → independent review。当前 R2 不执行该序列，不关闭 parent goal，
不授予 UP5/B00/B04/L4/R01-R10/provider/physical/engineering/search/formal credit。
