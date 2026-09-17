# M5-C R2 性能与语义修复范围合同

状态：`review_pending` / `not_implemented`  
合同版本：`M5CPerformanceRepairScopeContractR2V1`  
证据范围：`manufactured_conditional_egraph/screen_only`  
证据上限：`synthetic_egraph_equality/screen_only`；`formal_credit=none`

本合同是一个待评审的实现范围，不是实现记录，也不是运行授权。当前
checkout 只允许新增本目录合同文件；本轮不改生产源码、测试源码、性能
probe、历史 raw 或任何共享 registry。Julia、DESC、S3、mesh、solver、
provider、candidate、vehicle 均禁止启动。

## 1. 输入与 fresh freeze

本合同吸收以下只读资料：

- `M5-C-PERFORMANCE-R2/00-static-audit/{report.md,manifest.json}`；
- `M5-C-PERFORMANCE-R2/01-profile/{profile_report.md,measurements.json,bottleneck_hypothesis.json,manifest.json}`；
- `M5-C-PERFORMANCE-R2/reviews/01-profile-independent-review-r1/{judgment.md,manifest.json,raw/independent_checks.txt}`；
- `M5-EGRAPH-R2/00-gap-audit/{gap_audit.md,manifest.json}`；
- 下表 fresh freeze 的当前源码、测试、oracle 和 probe bytes/hash。

Fresh freeze（2026-09-17T06:18:41.9641925+08:00；PowerShell PID
`101316`；HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d`；branch `main`；
当时 Julia process count `0`）：

| 类别 | 精确路径 | bytes | SHA-256 |
|---|---|---:|---|
| M5-A source | `src/RuntimeV4/M4Isolated/ManufacturedAutoCompositionV1.jl` | 26258 | `284094e7781f41075915ab0f3b930e17e099e1fa45853218f2f639ea57e1a209` |
| M5-B source | `src/RuntimeV4/M4Isolated/ManufacturedInverseFeedbackV1.jl` | 26187 | `477b5a41c1a021fae84aeebaf13e3967c93b001ace7f38746af1ab1212110e59` |
| M5-C source | `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` | 23892 | `7a1f52a96a7a79061b1e4bdb0fc1b7b41de5e45266d0ac4726a50502a4dc6500` |
| core types | `src/IR/ConditionalEGraphTypes.jl` | 27558 | `885119aa142335f4dedcb1eb506b48350bc7793538b55d622ee9766e0ac47bee` |
| core saturation | `src/IR/ConditionalEGraphSaturation.jl` | 24038 | `643775a5b10b9865269c66088d97ff7476312924f324d9c8b75107ad7749cdb3` |
| core canonical | `src/Canonical/ConditionalEGraphCanonical.jl` | 18769 | `038c43431f053aa22ecac707a950aea19ae9d6a85157ce7d8325e43f3690eb12` |
| core typed-AST canonical | `src/Canonical/TypedASTProgramCanonical.jl` | 32199 | `b978fb99164f4d0f58c639f2e58dc1ecc3bc9baa2f9afdef63cd6e7c323809ff` |
| P1 core test | `test/conditional_egraph_p1_core_tests.jl` | 14685 | `a9216010bb1ed18959ffcf0f795c8dff40e1685e9c3e336b08d5811ad68d0ee3` |
| P1 hostile test | `test/conditional_egraph_p1_adversarial.jl` | 42284 | `df2ffdf8a2dabc20eecf786416aace65be8f50e39aede979bf5ea02b9a9318b4` |
| P1 length-hostile test | `test/conditional_egraph_p1_length_adversarial.jl` | 4960 | `33933587b0aeb14b2168198895541bfc20e4142e08cdc31adc136addc3db1ee1` |
| M5-C test | `test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl` | 14243 | `e0ed925a77f65aa045586f3c8dd78b2acfe8e023b29f1f95bba1f246b61a9355` |
| M5-C oracle | `test/RuntimeV4/M4Isolated/oracles/conditional_egraph_oracle_v1.py` | 4315 | `92db4edbea2060409d22ff453fa9eef119f8639f1ab6edb6cc01103218309dca` |
| M5-C performance probe | `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl` | 12817 | `7ea02e3d4ea313cdce5723150674a4c8b1440cb846faa3189535397471e56522` |

### 1.1 旧 scope hash 失效规则

所有旧 scope manifest、旧 scope decision 和旧 profile capture 的 hash 仅
作历史证据，不能作为本合同输入或实现放行依据。特别是旧 scope decision
中的 M5-A source `e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a`
与 M5-B source `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c`
已由当前 fresh freeze 的 `284094e7…` 与 `477b5a41…` 替代；旧 M5-C probe
capture `F01F480007814BE6504F4C7DC7FCC36039C2F7A4FB1751E9D6B680C0BB33FB88`
也已被当前 `7EA02E3D4EA313CDCE5723150674A4C8B1440CB846FAA3189535397471E56522`
替代。即使某些 core digest 数值相同，旧 scope 的整体身份仍然失效，不能
把旧 receipt 拼接到本合同的修复或性能结果。

## 2. 精确修改边界与归属

### 2.1 当前回合可写文件

当前回合精确可写集合只有：

1. `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/02-repair-scope-contract/contract.md`；
2. `docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/02-repair-scope-contract/manifest.json`。

不修改任何生产/测试源码，不修改 probe，不修改已有 `00-static-audit`、
`01-profile`、`reviews/01-profile-independent-review-r1` 或
`M5-EGRAPH-R2/00-gap-audit` 文件。

### 2.2 未来单独授权实现回合的允许集合

评审通过且另有实现授权后，允许修改的最小集合严格为下列四个 M5-C 局部
文件；归属不得转移：

| 文件 | 归属 | 允许内容 |
|---|---|---|
| `src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl` | M5-C adapter owner | derivation-local cache、preflight、条件 evaluator、完整 receipt binding、keyed dedup 和 API budget semantics |
| `test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl` | M5-C test owner | 正控、负控、语义/绑定回归、结果分类和 cache/canonical 不变性断言 |
| `test/RuntimeV4/M4Isolated/oracles/conditional_egraph_oracle_v1.py` | M5-C oracle owner | 与 M5-C evaluator 对应的独立 deterministic 参考模型；不得替代 Julia receipt |
| `test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl` | M5-C probe owner | 只记录本合同规定的阶段、预算、supervisor receipt 和计数修正 |

以下精确集合永远不在本修复范围内：M5-A/B source、上述四个 P1 core
source、P1 三个 test、`src/IR/ConditionalEGraph.jl`、shared entry、默认
operator registry、`Project.toml`、`Manifest.toml`、candidate/provider/
solver/physical/search 路径，以及所有历史 raw。若修复需要改其中任何一项，
本合同立即停止并要求新的 scope decision、fresh freeze 和独立评审。

## 3. 必须实现的语义与性能修复

### 3.1 derivation-local immutable canonical bytes/hash cache（P0）

在一次 derivation 内建立并传递只读、不可变的 sealed cache。cache 至少覆盖
typed-AST program、condition、rule、rewrite-set、member、provenance、trace
step，以及 derivation/graph/adapter receipt fragments 的 canonical bytes 和
hash；payload/hash/validation 必须复用同一 cache。cache 的 digest 必须由现有
canonical writer 产生的 bytes 计算。

cache 只能属于当前 derivation/product 的 immutable state；允许构造期的局部
临时查找，但不得有全局 mutable registry、跨 derivation memo、隐式 world
state 或可变对象逃逸。不得改 canonical bytes、字段顺序、规范化规则、排序、
witness tie-break、条件合并顺序或任何已有 hash 语义。正控必须证明修复前后
同一冻结输入的 sealed bytes/hash 与最终 tie-break witness byte-for-byte 相同。

### 3.2 projected-cost preflight → `terminal_deferred`（P0）

进入 rewrite-set 构造和 saturation 前必须运行保守 preflight；不能等 factorial
canonicalization 或 receipt full serialization 后才检查。估计至少纳入 AST 节点
数 `n`、`n!` canonical-order 上界、规则数 `R`、projected members、trace/
provenance 负担、canonical byte size、`max_bytes` 和请求 budget。计算溢出、非
有限或无法保守估计也按超界处理。

估计超过 lane budget 或安全字节上限时，必须产生带 estimate、limit、输入
hash、effective budget 和 reason 的 typed `terminal_deferred`，且不发布不完整
等价 hash、不开始后续饱和、不把它转成 `equality_unknown` 或成功。既有
post-build `max_bytes` guard 保留为第二道 receipt guard；preflight 不能放宽
`n=8`、`R=2`、`screen_only` 边界。

### 3.3 deterministic keyed dedup（P0/P1）

proposal/member/visited 的内部查找必须使用 sealed key 的 deterministic lookup。
key 必须包含能区分 canonical bytes 与累计条件的完整身份；仅以未验证的短 hash
去重不够，碰撞或同 key 异 bytes 必须 `fail_closed`。最终 emission 仍按当前
canonical byte order 和既有 witness tie-break 排序，不能以 map iteration order
决定输出。不得删除 provenance、condition、identity、trace replay 或 fail-closed
检查。

### 3.4 真实 condition evaluator 与失败语义（P0）

M5-C 必须接收一个版本化、候选绑定的 available-condition envelope，并实际
评估八类 frozen condition：`type`、`rank`、`domain`、`unit`、`port`、`owner`、
`interface`、`conservation`。catalog shape/hash 自洽不等于条件满足；每条 rule
只有在全部 required conditions 真实为 true 时才能产生 conditional merge。

失败分类固定如下：

| evaluator 结果 | graph/query 语义 |
|---|---|
| 全部满足 | 可按既有规则生成 `conditional_equal`，仍须完整 provenance/replay |
| 缺失、未知或不适用事实 | `condition_unmet`，不 merge；查询为 `equality_unknown` |
| 明确冲突、矛盾或 foreign fact | `fail_closed`；不 merge、不发布等价 hash |
| malformed/duplicate/foreign catalog 或 evaluator fault | typed `fail_closed`，不得伪装成 unmet |

`condition_unmet` 不得降级为 inequality；contradiction 不得被重写为
`equality_unknown`。oracle 只作独立参考，不是 Julia evaluator 的替代品。

### 3.5 budget 参数不可静默忽略（P0）

每个入口必须在 receipt 中记录 `requested_budget`、`effective_budget`、
`budget_applied` 和适用 reason。传入的 budget 必须真的约束该 derivation；
不同于 sealed product budget 的 object-level saturation 请求必须显式 rebuild
或显式 typed reject/deferred，绝不能返回原对象并暗示新预算已生效。只在未传
新 budget 或请求与 sealed budget 完全相同时才允许 identity-preserving no-op，
且 receipt 需写明 `no_op_reason`。任何超限只能按既有 bounded
`terminal_deferred` 路径表达。

### 3.6 全链条 identity/receipt binding（P0）

validator 必须对每个 immutable product 逐项检查并在 receipt 中显式保存：

- M5-A source identity、composition hash 与其 canonical source/program；
- M5-B source identity、`m5b_inverse_hash`、M5-A upstream hash，以及 owner
  bindings 和 provenance bindings；
- 八类 condition 的完整 catalog bytes/hash、ref、expected hash 和 available
  envelope/evaluation receipt；
- rewrite-set identity、每条 rule/hash/checker 与 source program；
- derivation identity、budget/profile、source hash、saturation state/stop reason、
  usage、trace/provenance 和 artifact hash；
- graph identity、graph source hash、members/conditions、以及
  `derivation.artifact === graph` 的对象关系和 canonical hash 关系；
- adapter schema、claim ceiling、evidence scope、status 与 complete/deferred
  一致性。

缺失、foreign、篡改、脱链或 status/graph/derivation 不一致均为 typed
`fail_closed`。尤其禁止 `graph != nothing` 而 derivation 缺失仍被接受，禁止
只校验间接 hash 而跳过 inverse/owner/provenance/catalog/rewrite 任一层。

## 4. 正控、负控与 core regression

### 4.1 必须保留的正控

1. 相同冻结 M5-A/M5-B、相同 catalog、available facts、profile、budget 的两次
   derivation，canonical bytes/hash、graph、usage、trace 和 witness 完全一致。
2. 八条件全部满足时，正向/反向 rule、query、100% trace replay、payload/hash/
   validate 均可复核，且仍为 `screen_only`。
3. cache on/off 参考实现（或 sealed baseline）在 bytes/hash/status/tie-break
   上完全相同；cache 命中不能改变 artifact identity。
4. 四个预算 lane 按第 5 节顺序各自产生 budget/result receipt；允许
   `terminal_deferred`，不把 deferred 当 pass。

### 4.2 必须保留的负控

覆盖每个 M5-A/M5-B/inverse/owner/provenance/catalog/rule/derivation/graph
字段的 missing、foreign、altered、duplicate、wrong-link、status mismatch、
detached artifact；覆盖每种 condition 的 unmet 与 contradiction；覆盖
zero attempts/rounds/traces、超 program/attempt/bytes、overflow/NaN、trace
tamper、hash collision-or-different-bytes 和 budget ignored。所有负控都需
typed reason，不能只断言 `false`。

还需保留 P1 hostile-process 约束：恶意 `Tuple`、`length`、`iterate`、`push!`、
property、equality 和 dispatch 扩展不能改变 core 或 M5-C 的 sealed output；
M5-C adapter 不得借动态迭代/全局别名绕过 core authority。

### 4.3 core regression（实现回合才可运行）

实现后先验证四个 core source hash 不变，再按独立进程串行运行以下既有回归；
本合同回合不运行：

```text
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_core_tests.jl
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_adversarial.jl
julia --startup-file=no --history-file=no --project=. test/conditional_egraph_p1_length_adversarial.jl
```

任何 core source/test hash 漂移、失败、非零退出、缺 raw 或 hostile-process
收据缺失，都阻止 M5-C 性能门；不得用 adapter 局部通过覆盖 core regression。

## 5. 性能门与监督收据

性能门是顺序门，不得跳过：

1. 先修正 probe capture/current identity，并生成新 manifest/measurements；
2. 单独取得完整 `prepare_rewrite_set` receipt；没有该 receipt，后续均为
   `not_measured`，不得声称 saturation 性能；
3. 依次执行 saturation budget：`2/4/1/2`、`3/8/2/3`、`4/16/3/4`、`8/32/4/8`，
   顺序分别为 `max_programs/max_rewrite_attempts/max_rounds/max_trace_steps`；
4. 仅在相应 budget/result receipt 完整后执行 `query`、`replay`、`validate`，并
   保存目标、provenance、replay 和完整 validation receipt；
5. 汇总前重新计算所有 raw bytes/hash、PID、UTC 区间和计数。

每个 probe 的 supervisor wall-clock 上限为 **60 s**，全部 probe 的累计上限为
**600 s**；一次只允许一个 Julia 进程。超时、人工停止或 supervisor kill 均为
`human_interruption`/timeout-like，结果为 `terminal_deferred` 或
`not_executed`，绝不是 valid/pass。阶段没有 receipt 时写 `not_measured`，不能
写 0。60 s 是硬门，不因某个子阶段“快要完成”而延长。

每次 supervisor receipt 至少包含：完整 command、`--startup-file`/
`--history-file` flags、cwd、host、supervisor PID、child PID/parent PID、启动前
后 Julia process count、UTC start/end、deadline、termination/kill 方式、原始
exit code、timeout 分类、stdout/stderr 路径、bytes/hash、输入/输出 artifact
hash、budget/stage、以及 receipt 自身 hash。PID/UTC/raw 的声明不能替代
supervisor 的实际收据；harness `program_exception` 必须和 timeout/interruption
分开。

历史 profile 的 raw 永不回写或重命名。旧 capture probe 为
`F01F4800…`、当前 probe 为 `7EA02E3D…` 且旧记录 `rerun=false`；因此旧 raw
只能标为 capture-version evidence。历史 `measurements.json` 的计数
`5/5/5/3/3` 不可直接复用；独立复核由 raw 支持的校正计数是：

| stage | raw-supported count |
|---|---:|
| include | 8 |
| upstream_first_compile_plus_build | 8 |
| upstream_warm_build | 8 |
| prepare_condition_catalog | 4 |
| prepare_rhs | 4 |
| prepare_source_cold_hash | 2 |
| prepare_rewrite_set（旧 profile） | 0, `not_measured_timeout_before_receipt` |

校正信息写入新 manifest/measurements 或新 run 目录，不改历史 raw。新 probe
run 必须同时记录实际 count；若 count 与 raw 不一致，则 receipt 无效并回到
`review_pending`。

## 6. 明确不授权与退出条件

本合同不授权 Julia/DESC/S3/solver 运行，不授权生产或测试源码变更，不授权
修改共享 core/registry，不授权扩大 AST、rule、budget、物理、provider、search
或 candidate scope，不授权正式 UP5-01、B00/B04、L4、R01-R10、physical、
engineering、provider 或 formal equivalence credit。通过本地测试、文档、probe
receipt、缓存命中或 supervisor exit 码都不能关闭 frozen parent goal。

实现回合只有在独立评审确认所有文件仍属上述集合、fresh freeze 已重建、正负
控和 core regression 完成、性能顺序门完整、timeout/raw/count 收据可复查后，
才可以把本合同从 `review_pending` 推进到新的实现状态；本文件当前仍保持
`review_pending/not_implemented`。
