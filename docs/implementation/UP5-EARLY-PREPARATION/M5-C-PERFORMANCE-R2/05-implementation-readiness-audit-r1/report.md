# M5-C implementation-readiness audit R1

## 结论

这是一次只读准备审计。审计期间没有启动 Julia、M5-C probe、DESC、S3、solver 或性能执行；只读取源码/既有 raw、计算文件哈希、读取 git 状态和 Julia 进程数。当前 checkout 为 `main@b2c04d8339774635aaecd73651efcdb101e01b5d`，工作树有大量既有 dirty changes；本报告没有改动它们。

当前实现可以在合同批准后先做“adapter 层的 preflight、catalog receipt、cache 数据结构、测试和证据编排”，但不能仅用现有四个 M5-C owner 文件修复 core saturation/canonicalization 的实际热点。原因是合同把四个 P1 core source 排除在写集合之外，而热点位于这些 source 的内部 API。若 04 合同的目标包括实际消除 factorial canonicalization、重复 canonical/O(M²) 扫描或替换 key，必须在实施前重新 scope/freeze，并显式允许对应 core seam；否则只能交付 fail-before-expensive-work、receipt 和等价性保持的 adapter 层改动，不能宣称性能修复。

## 审计冻结与输入

冻结时间：`2026-09-17T03:22:19.4729524Z`；`julia_process_count=0`；工作树状态不是 clean。完整 bytes/SHA-256 见同目录 `hash_manifest.json`，冻结元数据见 `freeze_receipt.json`。

重点输入及当前 hash：

| 层 | 文件 | bytes | SHA-256（小写） |
|---|---|---:|---|
| adapter | `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` | 23892 | `7a1f52a96a7a79061b1e4bdb0fc1b7b41de5e45266d0ac4726a50502a4dc6500` |
| CEG types | `src/IR/ConditionalEGraphTypes.jl` | 27558 | `885119aa142335f4dedcb1eb506b48350bc7793538b55d622ee9766e0ac47bee` |
| saturation | `src/IR/ConditionalEGraphSaturation.jl` | 24038 | `643775a5b10b9865269c66088d97ff7476312924f324d9c8b75107ad7749cdb3` |
| CEG writer | `src/Canonical/ConditionalEGraphCanonical.jl` | 18769 | `038c43431f053aa22ecac707a950aea19ae9d6a85157ce7d8325e43f3690eb12` |
| AST canonicalizer | `src/Canonical/TypedASTProgramCanonical.jl` | 32199 | `b978fb99164f4d0f58c639f2e58dc1ecc3bc9baa2f9afdef63cd6e7c323809ff` |
| M5-C test | `test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl` | 14243 | `e0ed925a77f65aa045586f3c8dd78b2acfe8e023b29f1f95bba1f246b61a9355` |
| M5-C probe | `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl` | 12817 | `7ea02e3d4ea313cdce5723150674a4c8b1440cb846faa3189535397471e56522` |

既有 profile 的结论只能作为历史诊断：cold source hash 约 25.6–26.4 s、约 9.25 GB allocation；`prepare_rewrite_set` 和 saturation 在 deadline 前没有完整 receipt，因此仍是 `not_measured`，不是零成本或成功。

## 当前调用链与风险定位

### 1. Factorial canonicalization

`TypedASTProgramCanonical.jl:335-360` 枚举所有 `n!` permutation，`_tac_program_payload:363-378` 对每个 permutation 构造 candidate 并重新序列化；`_typed_ast_program_json:633-635` 每次调用都重新进入这条路径，`canonical_hash:659-660` 再调用一次。`n=8` 时上限是 40320 个 order；canonicalization profile 的 refinement/search/vertex budget 不会截断该 permutation enumeration。所有以下调用点都可能重复支付它：

* `ConditionalEGraphTypes.jl:46-50, 103-114, 124-147, 162-178` 的 rule/trace/member/e-class construction；
* `ConditionalEGraphSaturation.jl:163-167, 180-186, 195-218` 的 source/rule/proposal/provenance/visited 路径；
* `ConditionalEGraphCanonical.jl:28-66` 的 rule/member/provenance/equivalence/attempt receipt writers；
* adapter `ManufacturedConditionalEGraphV1.jl:411-438` 的 payload/hash/validate 重复调用。

**准备判断：** preflight 可以在 adapter 侧用饱和算术估计 `n!` 并在 full canonical order 前返回 `terminal_deferred`；但真正的 warm/cached canonical bytes 不能被 adapter 传入当前 core API。若要使 saturation/receipt 使用同一 sealed bytes，至少需要 core 内部的 `canonical bytes/hash` cache seam 或 context 参数。

### 2. 重复 canonical 与 O(M²) 扫描

`ConditionalEGraphSaturation.jl:178-186` 每个 active member/rule pair 重新求 member/lhs/rhs AST bytes，并重新 merge conditions。`195-204` 对每个 proposal 重新生成 provenance bytes；`196-202` 用线性 `best` 扫描做 proposal dedup；`208-209` 用线性 `visited_keys` 扫描；`ConditionalEGraphTypes.jl:343-354` 的 insertion sort 又是 O(k²)。因此 count cap 只限制总量，不消除重复序列化和线性查找。

`ConditionalEGraphTypes.jl:204-224` 的 query 对 e-class members 线性扫描，并为每个 member 重新 canonicalize；`ConditionalEGraphSaturation.jl:236-265` 的 replay 每步线性扫描 rules，并重新 canonicalize current/expected/next/conditions。

**准备判断：** 最小正确优化是 derivation-local sealed byte cache 加 deterministic lookup index；保留 full-byte comparator 和原 witness tie-break。不能把 Julia `Dict` 的 iteration order、对象地址、`repr` 或截断 digest 作为 emission identity。

### 3. cache key 与 escape

当前 key 仍为字符串拼接：`_ceg_member_key`（`ConditionalEGraphSaturation.jl:95-96`）和 `_ceg_proposal_key`（`:123`）用 `"\0"` 连接 rule/program/orientation/conditions；`visited` 只保存 `Vector{String}`（`:161-168`、`:208-209`）。它没有合同要求的 domain、candidate/upstream identity、完整 length-delimited bytes 或 collision receipt，也没有 cache owner/escape 字段。

**准备判断：** adapter 可以先定义并 seal `M5CByteKeyV1`/`M5CCacheV1`，用于 catalog/source/rule preparation 和 receipt；但要替换 saturation 的 proposal/member/visited identity，必须让 core saturation 接受/生成该 key，或扩大 scope 允许 core source 修改。cache 必须 derivation-local、不可变、无 global memo、无跨 product hit，且 payload/hash/validate 共享同一 sealed entry。

### 4. supervisor

现有 probe `profile_probe.jl:37-44` 只用 Julia `@timed`，`102-109` 输出启动行，`185-203` 顺序尝试 budget，`219-250` 在同一进程继续 public build/query/replay/validate。它不产生合同要求的 supervisor PID、child PID/parent PID、前后 Julia count、UTC deadline、raw exit、timeout classification、stdout/stderr SHA 或 receipt SHA。

**准备判断：** probe 可在其 owner 文件内改为“一个 stage 一个子进程”的输出协议，但真正的进程监督、deadline、raw 保全和 post-count=0 必须由外部 PowerShell supervisor 负责；timeout/human kill 只能是 `terminal_deferred`/`not_executed`，不能变成 pass。probe 修订不得覆盖 `01-profile` 历史 raw。

## 04 合同获批后的最小文件归属

### 合同当前允许的四个 owner 文件

| owner | 精确路径 | 最小职责 | 不应承担 |
|---|---|---|---|
| M5-C adapter | `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` | preflight、八条件 envelope/evaluator、derivation-local cache、typed receipt/budget branch、adapter payload binding | 不修改 shared registry；不伪造 core graph 的 cache 命中；不改 claim ceiling |
| M5-C test | `test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl` | 正控、deferred/fail-closed、catalog、cache ownership/escape、key collision、canonical identity 与 hostile 负控断言 | 不删减既有 replay/tamper/zero-merge coverage |
| M5-C oracle | `test/RuntimeV4/M4Isolated/oracles/conditional_egraph_oracle_v1.py` | 独立 deterministic expected-union/key/condition 参考；只作交叉检查 | 不替代 Julia receipt 或改变 hard gate |
| M5-C probe | `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl` | 固定 stage/budget 顺序、compact stage payload、将 supervisor metadata 传递到 evidence receipt | 不在 probe 中并发跑 Julia；不覆盖历史 raw |

这四个文件可以交付 adapter-side preflight 和证据 schema，但不能独立完成 core inner-loop performance repair。

### 若 04 合同要求“实际修复热点”，需先扩大的 API seam

建议最小新增授权（不是本回合执行）：

1. `src/Canonical/TypedASTProgramCanonical.jl`：增加 sealed canonical bytes/hash 的显式、纯函数 cache seam，或让调用者携带 derivation context；不得改变既有 canonical bytes/hash。
2. `src/IR/ConditionalEGraphTypes.jl`：rule/condition/member/trace constructors 接收已 sealed bytes/hash，避免 constructor 内再次 canonicalize；保留字段校验。
3. `src/IR/ConditionalEGraphSaturation.jl`：建立 per-derivation rule/program/condition byte tables，proposal/member/visited 使用 length-delimited `M5CByteKeyV1` 和 deterministic index；replay 使用 rule `(ref,hash)` index。
4. `src/Canonical/ConditionalEGraphCanonical.jl`：receipt fragment cache 和 conservative size estimate；`_ceg_equivalence_bytes`/`_ceg_attempt_bytes` 不得递归重写同一 fragment。

这四个文件正是当前合同列入永久排除集合的 P1 core source。若不加入 owner 列表，以上只能记录为“未修复的结构性风险”，不能在验收中写成 cache/key/performance closed。`src/IR/ConditionalEGraph.jl`、shared entry、default registry、Project/Manifest 和 P1 core tests 仍应保持排除。

## API 改动点（实施顺序）

1. **入口 preflight：** 在 adapter build 进入 `_m5ceg_rewrite_set` 前读取 `n`、`R`、budget、`max_bytes`，用 UInt128 saturating arithmetic 生成 `M5CPreflightReceiptV1`。`decision=defer` 必须不调用 rewrite-set constructor、full canonical writer、proposal/member/visited emission；返回 `terminal_deferred`，不发布等价 hash。
2. **catalog：** 在现有 `ManufacturedConditionalEGraphConditionV1` 旁增加 versioned available envelope/evaluation receipt（或以兼容 sidecar 保持旧字段），固定八种 kind 顺序；缺失、重复、foreign、contradiction 与 unknown 必须保持不同 typed reason。
3. **cache：** adapter 侧增加 `M5CCacheV1`（owner/cache id/immutable entries/escape flags），所有 source/catalog/rule fragments 只从 sealed entry 读取。若要覆盖 core saturation，需采用上一节的 context/bytes API，而不是 global memo。
4. **key：** 增加 `M5CByteKeyV1` 的 magic/version、字段计数、big-endian byte length 和 full-byte equality；digest 只能索引，命中必须逐字节确认。core saturation 要么调用该 API，要么该项仍为未闭合。
5. **budget/status：** 所有 build/saturate/query/replay/validate 入口统一保存 requested/effective/applied/reason/sealed budget hash；sealed product 的不同 budget 是 `budget_mismatch`，不是 silently rebuild 或 `equality_unknown`。
6. **supervisor receipt：** probe 每个 stage 单独启动，外部 supervisor 填 `M5CSupervisorReceiptV1`；stage 顺序固定为 core regression → `prepare_rewrite_set` → 四个 saturation lanes → query/replay/validate。

## 基线命令（仅列出，审计中未运行）

### 静态冻结/复核

```powershell
git rev-parse HEAD
git branch --show-current
Get-Process -Name julia -ErrorAction SilentlyContinue
Get-FileHash -Algorithm SHA256 <frozen-inputs>
rg -n "_tac_permutations|_typed_ast_program_json|_ceg_member_key|_ceg_proposal_key|visited_keys|best_count|ConditionalEGraphDerivationResultV1|@timed" src test
```

### 合同指定的 core regression（未来授权后，由 supervisor 串行执行）

```text
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_core_tests.jl
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_adversarial.jl
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_length_adversarial.jl
```

### 性能 stage（未来授权后）

使用当前 probe 的 stage enum，不复用历史 raw：先 `prepare_rewrite_set`，再串行执行 `2/4/1/2`、`3/8/2/3`、`4/16/3/4`、`8/32/4/8`（programs/attempts/rounds/trace），之后才执行 query/replay/validate。单 probe deadline ≤60 s，全体 Julia wall clock ≤600 s，一次最多一个 Julia process。缺前一阶段完整 receipt 时后一阶段是 `not_measured`，不是 0。

每个 stage 必须保留 stdout/stderr/combined raw、原始 exit、PID/父 PID、UTC start/end/deadline、前后进程数、bytes/SHA-256、input/output artifact hash 和 receipt SHA；timeout/human interruption 一律 deferred/not-executed。

## 轻量/重型串行边界

| lane | 允许内容 | 运行方式 | 禁止越界 |
|---|---|---|---|
| static/light | hash、rg、schema/receipt lint、Python oracle、preflight arithmetic、key byte unit tests | 无 Julia 或单一短-lived helper；不启动 probe | 不把静态成功当 runtime/performance |
| bounded Julia smoke | 三个 core regression、preflight/catalog/key/cache 正负控、最小 `2/4/1/2` | 每命令独立 supervisor、串行、≤60 s | 不跑默认 `64/4096/32/256` |
| bounded performance | 四个固定 saturation lanes、query/replay/validate | 串行，前一 receipt 完整后才进入下一 lane | 不并发 Julia，不覆盖历史 evidence |
| heavy/deferred | 默认大 budget、超过 max bytes、任何未估计 canonical、DESC/S3/solver/provider/physical/search | 本任务不执行；仅记录 terminal_deferred/not_executed | 不用 human kill 伪造 pass |

## 预计测试矩阵

| 维度 | 正控 | 负控/边界 | 预期证据 |
|---|---|---|---|
| preflight | `n=8,R=2` 小预算 admit | `n=9`、默认大 budget、UInt128 overflow、nonfinite/estimate unavailable、max_bytes 超限 | preflight receipt；canonical/rewrite flags 均 false on defer |
| catalog | 八 kind 固定顺序且全部 met | missing、duplicate kind/ref、foreign source/inverse/hash、unknown、not_applicable、contradiction | envelope/evaluation receipt，状态优先级可 replay |
| rewrite | 两条现有 synthetic rules，lhs/rhs/interface/hash 稳定 | altered lhs/rhs/hash、checker/source detached、不同 upstream | full binding receipt，fail_closed |
| canonical/cache | 重复同一 derivation bytes/hash 相同；payload/hash/validate 共享 entry | cross-derivation hit、mutable alias、seal 后 mutation、cache clear/drop、escape | cache receipt；identity/status/witness 不变 |
| keys | proposal/member/visited 相同 full bytes dedup | same digest/different bytes、domain confusion、different candidate/upstream、mutated key | `key_collision`/fail_closed，full-byte witness |
| saturation | 2/4/1/2 → 3/8/2/3 → 4/16/3/4 → 8/32/4/8 | zero rounds/attempts/traces、program/trace cap、fixed-point vs incomplete | usage/stop reason/trace/eclass hash；无完整 receipt 不升级 |
| query/replay | source reflexive、每个 provenance member query+replay | unknown target、tampered rule/hash/trace/conditions | equality status 与 replay bool 分离；不把 unknown 当 unequal |
| supervisor | completed、post Julia count 0、raw/hash 完整 | timeout、child fault、human kill、缺 PID/UTC/hash、残留进程 | `M5CSupervisorReceiptV1`；非 completed 不得 pass |
| independent oracle | Python expected union/key/canonical fixture agreement | hostile `Tuple/length/iterate/push!/property/equality/hash/dispatch` 扩展 | oracle receipt 只交叉验证，不成为 Julia authority |

## 放行判定

当前状态：`implementation_ready_for_adapter_only / core-performance-scope-blocked / screen_only`。

只有在以下条件同时满足后，才可进入实施回合：04 合同明确确认四个 owner 文件，或重新 scope 授权所需 core API seam；重新 freeze 后 source/test/oracle/probe hash 未漂移；preflight schema 与 key/cache ownership 通过独立审阅；所有 stage 使用统一 supervisor receipt。任何 source drift、detached binding、cache escape、collision、budget ignored、timeout 被标为 pass、或把 `not_measured` 当作 0，都保持 `review_pending`。

本报告不授予 UP5、B00/B04、provider、search、physical、engineering 或 formal-equivalence credit。
