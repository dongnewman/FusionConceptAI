# M5-C R2 repair-scope independent review R1

## 裁决

**裁决：不能授权实现；保持 `review_pending / not_implemented`。**

本复核只读审查了 `02-repair-scope-contract/**` 及其列出的
`00-static-audit`、`01-profile`、`reviews/01-profile-independent-review-r1`
和 `M5-EGRAPH-R2/00-gap-audit` 输入，并对当前文件做了 PowerShell 静态/hash
复核。没有启动 Julia、DESC、S3 或 solver；没有修改被审合同、生产源码、既有
测试、probe 或历史 raw。结论上限保持
`manufactured_conditional_egraph/screen_only`、`synthetic_egraph_equality/screen_only`；
`formal_credit=none`。

## 可接受的基线

1. 合同的 13 个 `frozen_inputs` 在本复核时 bytes/hash 全部匹配（raw 中
   `powershell_pid=11080`，UTC `2026-09-16T22:27:20.5824964Z`--
   `2026-09-16T22:27:20.6159758Z`，exit `0`）。HEAD 仍为
   `b2c04d8339774635aaecd73651efcdb101e01b5d`、branch `main`；检查时 Julia
   process count 为 `0`。
2. 旧 M5-A `e6262a11...1945a`、旧 M5-B `0445ec58...a936c` 与当前
   `284094e7...a209`、`477b5a41...0e59` 不同；旧 probe capture
   `F01F4800...3FB88` 与当前 `7ea02e3d...56522` 不同。故合同正确地把旧
   scope/profile receipt 限定为历史 capture-version evidence，不能拼接到
   当前实现或性能结论。
3. 合同正确保留了四个 M5-C 局部 owner、保护 P1 core/M5-A/M5-B、禁止共享
   registry 和物理/solver 路径，并明确 cache 不得改变 canonical bytes、字段
   顺序、排序或 witness tie-break；preflight 超界必须是
   `terminal_deferred`；八条件的 unmet/contradiction/fault 分类、预算顺序、
   `screen_only` 和 `formal_credit=none` 方向均正确。
4. 历史 profile 的校正计数应使用 raw 支持的
   `8/8/8/4/4/2/0`，而不是 `measurements.json` 的 `5/5/5/3/3`。rewrite-set、
   saturation、query、replay、validate 没有完整 receipt，必须继续
   `not_measured`。`reviews/01` 对这一点及当前 probe `rerun=false` 的判定仍然
   有效。

## P1 阻断项

### P1-01：实现文件边界与性能收据输出互相矛盾

合同第 2.2 节把未来实现可写集合严格限定为四个源码/test/oracle/probe
文件；但第 5 节同时要求生成新 manifest/measurements、每 probe 的 raw 和
supervisor receipt。新证据包没有路径、owner、schema 或被允许写入的集合。
在当前文字下，完成性能门必然越过文件归属边界，或者只能伪造/覆盖历史收据。

授权前必须增加一个独立、追加式的 evidence-run 目录（不覆盖历史 raw），列出
其 manifest/receipt/stdout/stderr 的精确路径和 owner，并把该目录加入“未来可写
证据”而不是四个 M5-C 源文件；实现源码集合仍维持四文件不变。

### P1-02：preflight 只有目标，没有可审计的执行合同

第 3.2 节要求估计 `n!`、规则、members、trace/provenance、canonical bytes
和 budget，但未冻结 estimate 的字段、整数溢出算法、无限/NaN 表示、估计
bytes 的保守来源，或证明 canonical writer 不会在 guard 前被调用。实现者仍可能
先走 factorial canonicalization，再“记录”一个 preflight，失去 stop-loss 的
意义。

应冻结一个 typed `preflight_receipt`：结构性输入 hash、`n`、`R`、每项上界、
饱和算术/overflow 标记、`estimate_bytes`、`limit`、requested/effective budget、
decision/reason，并明确其发生在 rewrite-set 构造和任何 factorial/full receipt
serialization 之前；估计不可保守计算时直接 `terminal_deferred`，不得发布
partial hash。

### P1-03：available-condition envelope 的 schema 与判定闭包未冻结

合同写明八类条件和四类结果，这是正确方向，但没有规定 envelope 的版本、候选/
M5-A/M5-B binding、每项 kind/ref/expected hash/available fact/status、canonical
顺序、duplicate 规则、`not_applicable` 与 unknown 的区别，以及多条事实冲突
时的优先级。当前 adapter 的静态证据仍显示没有 available-envelope/evaluator
或 preflight 符号（见 raw PID `26476`，exit `0`）；它只做 catalog shape/hash
自洽检查并无条件把 requirements 送入 core。oracle 不能替代 Julia receipt。

授权前必须冻结 Julia 的版本化 envelope/result union 和 rule-level evaluation
receipt，并给出八类各自的 met/unmet/unknown/not-applicable/contradiction/
foreign 控制；只有全部 required facts 为 true 才能建立 conditional merge。

### P1-04：full binding 仍不可直接验收，尤其是 upstream object relation

第 3.6 节列出了 inverse、owner、provenance、catalog、rewrite、derivation、
graph，但没有冻结 receipt 的字段级 schema、foreign/detached 检查矩阵，或如何
在 immutable product 中保留 M5-A/M5-B 的 canonical source/program 与 supplied
object relation。当前 validator 373--405 行对 `m5b_inverse_hash`、owner/
provenance 和 `derivation.artifact === graph` 没有引用（raw PID `62668`，exit
`0`）；仅靠间接 source hash 不能证明完整脱链控制。

必须增加逐字段 missing/foreign/altered/duplicate/wrong-link/detached/status
mismatch 预期 typed code，并冻结 upstream identity receipt、完整 catalog bytes/
hash、rewrite rule/checker source binding、derivation/graph object 与 canonical
hash 双重关系。`graph != nothing` 且 derivation 缺失必须明确 fail-closed。

### P1-05：budget API 的分支仍由实现者选择，无法形成单一验收语义

合同允许不同 object-level budget 选择“rebuild 或 reject/deferred”，但没有冻结
哪一个分支、错误码、是否保留原 identity、result wrapper 如何携带 receipt。
这会让同一请求既可被实现为隐式 no-op，也可被实现为重建而难以判定是否合规。

授权前应固定：未传 budget/与 sealed budget 完全相同才是带
`no_op_reason` 的 identity-preserving no-op；不同 budget 的 product overload
建议一律 typed `budget_mismatch` reject（input overload 才允许显式 rebuild）。
所有成功、deferred、reject、invalid 路径都必须写
`requested_budget/effective_budget/budget_applied/reason`。

### P1-06：deterministic keyed dedup 的 key/碰撞测试尚不足以授权

合同要求完整 sealed key、碰撞 fail-closed 和 canonical emission 排序，但未冻结
key 的 byte grammar、hash collision 注入方式、同 key 异 bytes 的比较步骤，以及
在 hostile `hash`/`==`/iteration/`Tuple` 扩展下 map lookup 的边界。现有 M5-C
adapter 静态扫描仍有 33 个 `push!`、8 个 `Tuple(`，而 P1 core 的 hostile
保护不自动覆盖 adapter。

实现合同必须指定 immutable byte-key（不能只用短 digest）、full-byte collision
check、固定排序 comparator 和 map iteration 不参与 emission；M5-C test 要有
可复现的 same-key/different-bytes、proposal/member/visited 三类负控，以及 fresh
hostile-process receipt。否则 cache/dedup 优化可能改变 witness 或绕开 authority。

### P1-07：core regression 与 supervisor gate 没有统一收据要求

第 4.3 节只要求实现后运行三个 core 命令并保留 raw/hostile receipt，第 5 节的
完整 supervisor 字段却没有明确覆盖这三个 regression 命令，也没有强制每个命令
记录 supervisor exit、child parent、前后 process count、kill/timeout 方式和
post-run Julia count。`reviews/01` 已指出旧 profile 只有 PID/UTC 声明、没有独立
supervisor/kill 取证。

应把三条 core 命令和四条性能 lane 纳入同一 supervisor receipt schema；每条独立
进程串行执行，记录 command/flags/cwd/host/supervisor PID/child PID-parent PID、
UTC/deadline、原始 exit、termination、stdout/stderr bytes/hash、输入输出 hash、
receipt hash，并验证运行后 Julia count 为 0。缺任何一项即阻断性能门。

## P2 完善项

1. `fresh_freeze` 记录了时间/PID/HEAD，但没有对应 capture command、exit、raw
   sidecar，也没有旧/current probe byte length 或旧 scope manifest 的精确
   input hash；文本说明足够人工阅读，机器重放仍不完整。建议增加
   `freeze_receipt` 与旧证据路径/bytes/hash。
2. 校正历史计数虽写入合同，但没有规定 raw stage 行到 corrected count 的一一
   映射，也没有把 probe 的 `prepare_rewrite_set_constructor` 与 gate 要求的
   `prepare_rewrite_set` 名称统一；应冻结 stage enum，避免把部分 constructor
   receipt 当完整 rewrite-set receipt。
3. “cache on/off reference implementation（或 sealed baseline）”给了两种未定
   选择。应冻结 baseline 的 source/hash、输入 envelope、profile/budget 和
   byte/hash/witness 比较字段；否则无法证明 cache 命中不改变 artifact identity。
4. cache 的不可变和 derivation-local 约束正确，但缺少 ownership/escape 负控（如
   重复 derivation、跨 product 复用、payload/hash/validate 三方共用同一 bytes
   的 receipt）。建议加入不涉及 Julia 重跑的 schema 断言和实现后 fresh test。

## 放行前的必要条件

只有在修正 P1-01--P1-07、重新生成 fresh freeze，并由独立评审确认四文件 owner、
typed evaluator/preflight/receipt schema、collision/hostile 控制、三个 core
regression 和完整 supervisor evidence package 后，才可另行授权一个 bounded
implementation turn。任何旧 source/probe hash、`program_exception`、timeout/
`human_interruption`、缺 receipt 或不一致 corrected count 都只能是
`terminal_deferred`/`not_measured`，不能当作性能 pass。

本复核没有运行任何实现或性能门，不能关闭 frozen parent goal，也不授予 UP5、
B00/B04、L4、R01-R10、provider、physical、search 或 formal equivalence credit。
