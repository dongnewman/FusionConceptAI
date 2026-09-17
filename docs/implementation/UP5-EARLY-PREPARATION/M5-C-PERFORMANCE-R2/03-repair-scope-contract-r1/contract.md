# M5-C R2 修订 scope contract（R1）

状态：\`review_pending\` / \`not_implemented\`  
scope：\`manufactured_conditional_egraph/screen_only\`  
claim ceiling：\`synthetic_egraph_equality/screen_only\`  
\`formal_credit=none\`

本文件是对 \`02-repair-scope-contract\` 的追加式修订，不是实现授权、性能结果或父目标关闭证明。它逐项关闭 \`reviews/02-repair-scope-independent-review-r1\` 的 P1-01..P1-07、P2-01..P2-04。实现必须另行授权；在授权前只允许写本 \`03-repair-scope-contract-r1/**\`。不得改写或删除旧 contract、旧 manifest、旧 raw，尤其不得改写 \`.../02-repair-scope-contract/**\`。

## 1. 硬边界与状态

本修订只允许以下非 Julia 的静态审计动作：读取现有文件、计算 bytes/SHA-256、读取 git HEAD/branch/status、读取进程数量和写入本修订目录的证据文件。禁止启动 Julia、DESC、S3、mesh、solver、provider、candidate、vehicle、search 或 physical 执行；禁止修改生产源码、任何已有测试、probe、共享 registry、core、历史 raw 和 \`02-repair-scope-contract/**\`。不可用文档、静态检查、缓存命中、supervisor exit 或本地测试替代物理/工程/provider/formal 证据。

所有产物仍保持：\`review_pending\`、\`not_implemented\`、\`screen_only\`、\`formal_credit=none\`。\`terminal_deferred\`、\`not_measured\`、\`program_exception\`、\`human_interruption\`、\`timeout\`、\`fail_closed\` 和 \`condition_unmet\` 是互斥的证据状态，不能重命名为 pass 或成功。

## 2. 精确路径、owner 与追加式 evidence-run

### 2.1 当前修订回合可写集合

当前回合只能新增或修改以下路径；所有路径均相对于 \`D:/006-Programing/LMC/FusionConceptAI\`：

| 路径 | owner | 用途 |
|---|---|---|
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/contract.md\` | scope owner | 本修订合同 |
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/manifest.json\` | scope owner | 本修订身份与清单 |
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/acceptance_matrix.md\` | reviewer/scope owner | P1/P2 字段级验收与负控矩阵 |
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/schemas/receipt_schema.json\` | scope owner | typed receipt 的机器可读 schema |
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/schemas/condition_envelope_schema.json\` | scope owner | available envelope/evaluation schema |
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/freeze_receipt.json\` | evidence owner | 本回合只读 freeze、PID/UTC/exit 与历史 capture 元数据 |
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/hash_manifest.json\` | evidence owner | 本回合 raw 与 frozen input 的 bytes/SHA-256 manifest |
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/raw/*.raw\` | evidence owner | 本回合只读命令原始输出；追加，不覆盖 |
| \`docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/**\` | evidence owner | **未来另行授权**后的追加式 raw/receipt/manifest |

省略号仅为上述长路径的显示缩写；实际可写根目录是精确的 \`.../03-repair-scope-contract-r1/\`。\`<run_id>\` 必须为不重复的 UTC 时间戳加单调序号；已存在 run 不得复用。证据目录不得 symlink、junction 或引用可变的共享 registry。

### 2.2 未来单独授权的实现与证据集合

实现回合仍只有四个源码 owner：

| 精确路径 | owner | 允许内容 |
|---|---|---|
| \`src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl\` | M5-C adapter | derivation-local immutable cache、preflight、condition evaluator、receipt binding、keyed dedup、budget 分支 |
| \`test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl\` | M5-C test | 正控/负控、状态/receipt/cache/canonical 不变性断言 |
| \`test/RuntimeV4/M4Isolated/oracles/conditional_egraph_oracle_v1.py\` | M5-C oracle | 独立 deterministic 参考 evaluator；不得替代 Julia receipt |
| \`test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl\` | M5-C probe | 只记录冻结 stage、budget、supervisor receipt 与校正计数 |

四个实现文件之外，未来 evidence 只可写：

\`\`\`text
docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/manifest.json
docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/freeze_receipt.json
docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/hash_manifest.json
docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/receipts/<stage>.json
docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/raw/<stage>.stdout.raw
docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/raw/<stage>.stderr.raw
docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/03-repair-scope-contract-r1/evidence-runs/<run_id>/raw/<stage>.combined.raw
\`\`\`

\`<stage>\` 必须为不重复的冻结 stage enum（见 §9）；禁止把 raw 放回历史 \`00\`、\`01\`、\`02\` 或 \`reviews/02\`。实现、测试、oracle、probe 和 evidence 各自 owner，不得互相覆盖；reviewer 只能新增 review 目录，不得修补输入。

### 2.3 永久排除集合

排除集合包括 M5-A/B、四个 P1 core source、P1 三个 core test、\`src/IR/ConditionalEGraph.jl\`、shared entry、默认 operator registry、\`Project.toml\`、\`Manifest.toml\`、所有 \`runs/**\`、provider/candidate/solver/physical/search 路径和所有已有 raw。任何修复若需要触碰这些路径，合同失效，必须重新 scope decision、fresh freeze 和独立评审。

## 3. P1-01：evidence-run 是追加式且有 schema

每次 future run 先建立全新的 \`<run_id>\`，随后只写 1 个 run manifest、1 个 freeze receipt、1 个 hash manifest、每个 stage 1 个 receipt 及对应 stdout/stderr/combined raw。manifest 必须列出每个文件的 owner、relative path、bytes、SHA-256、creation UTC、source run id 和 \`overwrites=[]\`；\`overwrites\` 非空即 fail-closed。manifest 自身 hash 使用 \`manifest_self_hash=excluded_by_policy\`，其余文件相互哈希。

历史证据只能以 \`source_run_id\`/\`historical=true\` 引用，不能复制、重命名或拼接。没有完整 evidence-run（manifest、freeze、stage receipt、raw/hash sidecar）时，阶段状态为 \`not_measured\`；绝不伪造 receipt 或覆盖历史 capture。

## 4. P1-02：typed preflight 与 guard-before-canonical 顺序

### 4.1 固定执行顺序

一个 derivation 的顺序严格为：

1. 校验输入对象是已 sealed 的上游 bytes/hash，并生成只读 \`structural_input_hash\`；
2. 读取 \`n\`、\`R\`、规则声明、预算和安全字节上限；
3. 运行 typed \`preflight_receipt\`；
4. 只有 decision=\`admit\` 才可构造 rewrite-set、调用任何 factorial/full canonical ordering、saturation 或 full receipt serialization；
5. post-build \`max_bytes\` guard 是第二道 guard，不能替代 preflight。

preflight 之前禁止调用 M5-C canonical writer、\`n!\` 的非饱和实现、rewrite-set constructor、proposal/member/visited emission、完整 provenance/trace 序列化，或发布任何 partial canonical hash。\`structural_input_hash\` 只能由输入已有 sealed bytes 计算；它不是 M5-C output hash。

### 4.2 receipt schema 与饱和算术

\`preflight_receipt\` 的 \`schema\` 固定为 \`M5CPreflightReceiptV1\`，必填字段为：

\`\`\`text
receipt_id, schema, derivation_input_hash, candidate_id, m5a_source_hash,
m5b_inverse_hash, n, rule_count, projected_members, projected_trace_steps,
projected_provenance_bytes, factorial_order_upper_bound,
projected_canonical_bytes, max_bytes, requested_budget, effective_budget,
arithmetic {base="UInt128", cap, saturated_fields[], overflow, nonfinite},
decision {admit|defer}, reason, guard_phase="before_rewrite_set_and_canonical",
canonical_writer_called=false, rewrite_set_constructor_called=false,
utc, producer_owner
\`\`\`

所有非负估计使用无符号饱和算术，\`cap = min(UInt128_MAX, max(limit,1)+1)\`；加法和乘法先做溢出预检，超过 cap 时返回 cap、记录字段于 \`saturated_fields\`、置 \`overflow=true\`。 \`n!\` 只允许逐项 saturating multiply，禁止实际 factorial/canonical 枚举。 \`NaN\`、\`Inf\`、负值、无法保守估计或结构化输入不完整时置 \`nonfinite=true\` 或 \`reason=estimate_unavailable\`，decision 必为 \`defer\`。

估计超过任一 lane budget 或 \`max_bytes\` 时 decision=\`defer\`，最终 typed 状态只能为 \`terminal_deferred\`，且必须有 estimate、limit、输入 hash、effective budget、reason；不发布等价 hash，不进入后续阶段。

## 5. P1-03：版本化 available-condition envelope 与状态优先级

### 5.1 envelope V1

唯一允许版本是 \`M5CAvailableConditionEnvelopeV1\`。必填 envelope 字段：

\`\`\`text
schema, envelope_version="v1", envelope_id, candidate_id,
m5a_source_hash, m5b_inverse_hash, catalog_ref, catalog_hash,
conditions[8], canonical_bytes, canonical_sha256, producer_owner
\`\`\`

\`conditions\` 必须按固定顺序：\`type, rank, domain, unit, port, owner, interface, conservation\`，每项为 \`{kind, ref, expected_hash, required, fact_status, fact_value, fact_hash, evidence_ref}\`。\`kind\` 不得重复；缺 kind、未知 kind、foreign candidate/source/inverse、重复 ref、错误 catalog hash、非法 canonical 顺序或 malformed field 均为 typed \`fail_closed\`，不得改写为 unmet。 \`not_applicable\`、\`unknown\`、\`absent\`、\`met\`、\`unmet\`、\`contradiction\`、\`foreign\` 是封闭枚举。

### 5.2 评价闭包与优先级

对每条 rule，evaluation receipt 固定为 \`M5CConditionEvaluationReceiptV1\`，含 rule id/hash、envelope id/hash、八项逐项结果、\`required_all_met\`、aggregate、reason 和 candidate/upstream binding。全局优先级从高到低固定为：

\`malformed | duplicate | foreign | evaluator_fault\` → \`fail_closed\`；\`contradiction\` → \`fail_closed\`；\`unknown | not_applicable | absent\` → \`condition_unmet\`（query=\`equality_unknown\`）；\`unmet\` → \`condition_unmet\`；只有八项 required 全部 \`met\` 才是 \`conditions_met\` 并允许 conditional merge。

\`condition_unmet\` 不得降级成 inequality；明确矛盾不得包装成普通 unknown；catalog shape/hash 自洽也不代表事实满足。oracle 必须独立计算预期 union，但 Julia evaluator 的 receipt 才是 adapter authority。

八种 condition 各至少有正控 \`met\`、缺失/unknown、\`not_applicable\`、明确 contradiction、foreign 负控；均需保存 rule-level reason 和逐项状态。

## 6. P1-04：完整 upstream/catalog/rewrite/derivation/graph 验收矩阵

每个 immutable product 都必须携带 \`M5CFullBindingReceiptV1\`，并对下列字段执行 \`present + exact bytes + sha256 + owner/ref + object relation\` 双重验证。字段缺失、foreign、altered、duplicate、wrong-link、detached、status mismatch 的预期 typed code 见 \`acceptance_matrix.md\`；任一失败即 \`fail_closed\`。

必验链为：M5-A source identity/canonical source/program/composition hash；M5-B source identity、\`m5b_inverse_hash\`、M5-A upstream hash、owner/provenance；八条件 catalog bytes/hash/ref/expected hash、available envelope/evaluation receipt；rewrite set identity、每条 rule/hash/checker/source program；derivation identity、budget/profile/source hash/saturation state/stop reason/usage/trace/provenance/artifact hash；graph identity/source hash/members/conditions；adapter schema/claim ceiling/evidence scope/status。

必须同时满足：\`derivation.artifact === graph\` 的对象身份关系、\`sha256(derivation.artifact_bytes) == graph.artifact_hash\` 的 canonical hash 关系、\`graph != nothing && derivation == nothing => fail_closed\`。仅验证间接 source hash、仅验证 graph 非空或仅验证 catalog shape 都不合格。任何 detached artifact、foreign upstream、inverse/owner/provenance/catalog/rewrite 任一层脱链均拒绝。

## 7. P1-05：固定 budget 分支和 receipt 字段

每个入口统一写 \`requested_budget\`, \`effective_budget\`, \`budget_applied\`, \`budget_reason\`, \`sealed_budget_hash\`, \`result_status\`。分支不可由实现者选择：

| 输入 | 唯一分支 | 要求 |
|---|---|---|
| budget 未传 | identity-preserving \`no_op\` | \`effective_budget=sealed_budget\`，\`no_op_reason=budget_omitted\` |
| budget 与 sealed 完全相同 | identity-preserving \`no_op\` | \`no_op_reason=budget_equal\`，原 artifact hash 不变 |
| sealed product 的 object-level budget 不同 | typed reject | \`status=budget_mismatch\`，不复用旧 artifact，不暗示新 budget 生效 |
| input 明确 overload（尚未 sealed） | 显式 rebuild | 新 \`derivation_id\`/\`artifact/hash\`，\`budget_applied=rebuild_input_overload\` |
| 任一预算超限 | deferred | \`status=terminal_deferred\`，完整 preflight/result receipt |

\`budget_mismatch\` 是 typed 非成功结果，不是 \`equality_unknown\`；invalid budget 为 \`fail_closed\`。所有上述路径都必须保存 requested/effective/applied/reason，即使 reject/deferred/no-op 也不能省略。

## 8. P1-06：不可变 byte-key、碰撞和 hostile 负控

proposal/member/visited 三类 key 共用不可变 \`M5CByteKeyV1\`。grammar 为：

\`\`\`text
ASCII("M5C-K1") || u16be(field_count) ||
repeat(field_count) [u32be(byte_length) || raw_bytes]
\`\`\`

字段顺序固定：\`key_domain\`, \`candidate_identity_bytes\`, \`upstream_identity_bytes\`, \`canonical_program_bytes\`, \`condition_bytes\`, \`provenance_identity_bytes\`；不得使用分隔符、字符串 repr、对象地址或截断 digest。key 先保存完整 bytes，再可用 digest 做索引；命中时必须逐字节比较。相同 key bytes 才允许 dedup；同 key/different bytes、同 digest/different full key、不同 domain 误合并均 typed \`key_collision\` 并 \`fail_closed\`。map iteration order 永远不参与 emission；输出使用固定 lexicographic full-byte comparator 加既有 witness tie-break。

M5-C test 必须可复现覆盖三类 proposal/member/visited 的 same-key/different-bytes、digest collision、domain confusion 和 mutated-after-seal key；并在独立 hostile process 注入恶意 \`Tuple\`、\`length\`、\`iterate\`、\`push!\`、property、equality、hash、dispatch 扩展，证明 sealed output/status/hash 不变。负控必须保存 typed reason 和 supervisor receipt，不得只断言 \`false\`。

## 9. P1-07：所有 core/perf 命令统一 supervisor receipt

唯一 schema 是 \`M5CSupervisorReceiptV1\`，适用于三个 core regression、一个 \`prepare_rewrite_set\` 和四个 saturation lanes，以及后续 query/replay/validate（若执行）。每条命令独立进程、串行、运行前后 Julia count 必须为 0。receipt 必填：

\`\`\`text
schema, run_id, stage, command, startup_file_flag, history_file_flag, cwd, host,
supervisor_pid, child_pid, child_parent_pid, pre_process_count, post_process_count,
utc_start, utc_end, deadline_utc, supervisor_wall_seconds, termination,
raw_exit_code, timeout_class, stdout_path, stderr_path, combined_path,
stdout_bytes, stdout_sha256, stderr_bytes, stderr_sha256, input_artifact_hash,
output_artifact_hash, budget, status, receipt_sha256
\`\`\`

\`termination\` 只能为 \`completed\`, \`supervisor_timeout\`, \`human_kill\`, \`child_fault\`；timeout/human kill 是 \`terminal_deferred\` 或 \`not_executed\`，不可是 pass。harness \`program_exception\` 与 timeout/interruption 分开。缺 supervisor PID、父子 PID、前后 process count、UTC/deadline、raw bytes/hash、原始 exit、receipt hash 或 \`post_process_count=0\`，整条命令无效并阻断性能门。

冻结命令为：

\`\`\`text
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_core_tests.jl
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_adversarial.jl
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_length_adversarial.jl
\`\`\`

性能顺序固定：先 \`prepare_rewrite_set\` receipt，再按 \`2/4/1/2\`、\`3/8/2/3\`、\`4/16/3/4\`、\`8/32/4/8\`（programs/attempts/rounds/trace）串行执行；没有前一 receipt，后一阶段为 \`not_measured\`。单 probe ≤60 秒、全体 Julia ≤600 秒且一次只允许一个 Julia 进程。

## 10. P2-01/02：唯一 freeze receipt、stage enum 与校正计数

每个 evidence-run 只有一个 \`M5CFreezeReceiptV1\`，包含 capture command、PowerShell PID、UTC start/end、HEAD、branch、cwd、pre/post process count、source/test/oracle/probe bytes/hash、旧 evidence path/bytes/hash、命令 exit 和 freeze receipt hash。旧 probe capture \`F01F4800...3FB88\` 与当前 probe \`7EA02E3D...56522\` 必须分开记录；旧 source hashes 不能当 current identity。freeze 失败则 run=\`review_pending\`。

stage enum 只允许：\`include\`, \`upstream_first_compile_plus_build\`, \`upstream_warm_build\`, \`prepare_condition_catalog\`, \`prepare_rhs\`, \`prepare_source_cold_hash\`, \`prepare_rewrite_set\`, \`saturate_budget_2_4_1_2\`, \`saturate_budget_3_8_2_3\`, \`saturate_budget_4_16_3_4\`, \`saturate_budget_8_32_4_8\`, \`query\`, \`replay\`, \`validate\`。

历史 profile raw 行到 corrected count 的固定映射为：

| enum | raw-supported corrected count | 解释 |
|---|---:|---|
| include | 8 | raw 中 8 个 include 行 |
| upstream_first_compile_plus_build | 8 | raw 中 8 个 first compile/build 行 |
| upstream_warm_build | 8 | raw 中 8 个 warm build 行 |
| prepare_condition_catalog | 4 | raw 中 4 个 catalog 行 |
| prepare_rhs | 4 | raw 中 4 个 rhs 行 |
| prepare_source_cold_hash | 2 | raw 中 2 个 source cold hash 行 |
| prepare_rewrite_set | 0 | 旧 raw 在完整 receipt 前超时，\`not_measured_timeout_before_receipt\` |

\`prepare_rewrite_set_constructor\` 不是合法 stage，不能冒充 \`prepare_rewrite_set\`。新 run 必须用同一 enum、列出 raw 行 id 与 count；count/raw 不一致为 \`fail_closed\`，历史 \`measurements.json\` 的 \`5/5/5/3/3\` 不可复用。无 receipt 的阶段写 \`not_measured\`，不能写 0。

## 11. P2-03：唯一 baseline freeze

cache 比较唯一基线为 \`M5C-R2-FROZEN-BASELINE-V1\`：当前 fresh freeze 的 M5-C adapter source、四个 M5-C owner 文件、四个 core source、同一 candidate-bound envelope、同一 profile 和同一 lane budget 的**未修复 sealed baseline capture**。baseline 必须记录 source/program/canonical bytes/hash、input envelope bytes/hash、profile/budget、graph/usage/trace/witness 字段和 baseline receipt hash；不得再以“cache on/off reference 或 sealed baseline”二选一。修复后 cache-on artifact 只能与这个唯一 baseline 比较，要求 bytes/hash/status/tie-break/witness 完全一致；baseline 不得被修复实现覆盖。

## 12. P2-04：cache ownership/escape controls

cache 类型必须为 derivation-local immutable \`M5CCacheV1\`，owner 是当前 \`derivation_id/product_id\`；所有 canonical bytes/hash/validation 必须来自同一 sealed entry。禁止 global mutable registry、跨 derivation memo、跨 product reuse、隐式 world state、可变 key、对象地址和 cache 引用逃逸。实现测试必须覆盖：重复相同 derivation 产生新 cache 但相同 bytes/hash；不同 derivation/product 不命中；payload/hash/validate 共享 entry bytes；seal 后 mutation、cache alias、clear/drop 后使用均 typed fail-closed 或 no-op，不得改变 identity。receipt 应写 \`cache_owner\`, \`cache_id\`, \`entry_count\`, \`shared_entry_ids\`, \`escape_detected\`, \`cross_derivation_hit\`。

## 13. 顺序放行与证据上限

实现授权后顺序必须是：fresh freeze → core source hash recheck → preflight/schema 测试 → M5-C 正负控与 oracle 交叉检查 → 三条 core regression → prepare receipt → 四个 budget lanes → query/replay/validate → 独立审阅。任何缺 raw/PID/UTC/exit/hash、source drift、supervisor 缺字段、超时、program exception、count 漂移、detached binding、collision、budget ignored、condition fault 或 cache escape 都保持 \`review_pending\`，相应结果为 \`terminal_deferred\`/\`not_measured\`/\`fail_closed\`。

本合同修订本身不运行上述命令，不能关闭 P1/P2 的实现后验证，也不授予 UP5-01、B00/B04、L4、R01-R10、physical、engineering、provider、search 或 formal equivalence credit。所有当前声明的 raw、PID、UTC、exit、hash 仅来自本目录的只读审计或明确标注的历史 capture。
