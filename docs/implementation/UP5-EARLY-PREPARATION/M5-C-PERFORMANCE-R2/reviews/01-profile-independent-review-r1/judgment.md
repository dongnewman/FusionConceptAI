# M5-C Performance R2 independent profile review R1

## 判定

**判定：部分可用，不能作为实现放行或性能闭环。** 本复核只读检查了
`00-static-audit/**`、`01-profile/**` 和
`test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl`；没有启动 Julia、DESC、
S3 或 solver，也没有修改被审文件、生产源或既有测试。结论上限保持
`manufactured_conditional_egraph/screen_only`，`formal_credit=none`。

可以使用的证据是：

1. 静态审计所列 8 个冻结输入的当前 bytes/hash 全部相符，HEAD 为
   `b2c04d8339774635aaecd73651efcdb101e01b5d`、branch 为 `main`；当前 checkout
   与审计声明一致地是 dirty。
2. 8 个 profile raw 进程的 stdout/stderr bytes 与 SHA-256 全部复算通过；8 个
   PID 互不重复，manifest 中的 PID 与对应 raw 的启动行一致；各 UTC 区间互不
   重叠。它们是记录完整性证据，不是独立的 OS 进程取证。
3. raw 实际支持的冷阶段数值为：include `0.9937596–1.3641471 s`、
   upstream 首次编译+构建 `10.2660510–13.1685758 s`、warm build
   `0.0049250–0.0081767 s`、condition catalog `7.4698831–11.9444217 s`、
   RHS `0.0749638–0.1326588 s`，以及 cold source canonical hash
   `25.6356897–26.3727920 s`、`9,253,714,448` allocated bytes。数值来自 raw
   stage receipts；它们只能描述 fresh-process/cold-preparation 层。
4. `prepare_source_cold_hash` 是当前可用的最强实测瓶颈候选，但“method
   compilation/allocation amplification 主导”的因果归因仍是 cold-preparation
   假设；不能外推为 saturation 性能结论。
5. `profile_probe.jl` 当前实现的 `_tac_program_payload` 直接调用
   `_tac_permutations(n)`，并遍历 `total=n!` 个 order。`n=8` 时枚举数精确为
   `8! = 40,320`。profile 的 search/refinement/vertex budget 不在该函数调用链
   中，因此“存在 factorial canonical path、budget 不会提前短路该枚举”这一静态
   结论成立。`Theta(n! * n^2 * serialized-node-size)` 是渐近工作量模型，
   不是一次独立 runtime 测量。

## 不可用 / `not_measured`

以下均没有完成 receipt，必须保持 `not_measured`，不能记为 0、成功或失败：

- rewrite-set construction（包括 fast 两次尝试）；
- saturation 的全部 budget lane（包括计划中的
  `2/4/1/2`, `3/8/2/3`, `4/16/3/4`, `8/32/4/8`）；
- graph counters `programs/nodes`, `trace_steps/edges`, `rewrite_attempts`,
  `rounds`；
- query、replay、validate、budget-result/derivation receipt；
- steady-state graph size、saturation complexity、budget scaling、query/replay/
  validation cost。

`rules_parts_harness` 的 exit 1 有 321-byte stderr，内容是
`invalid redefinition of constant Main.source`（probe line 131），因此可分类为
**test-harness `program_exception`**，不能分类为 rewrite-set/application
exception。当前 probe 已把该全局名改为 `src_program`，但 capture 后 hash 已变化且
未重跑；所以该修复后的路径仍然是 `not_measured`。

## Stop-loss、总量与分类核对

manifest 的 `max_probe_seconds=60` 与所有单进程记录相容：UTC 区间的精确时长
为 `55.0572187, 32.3995274, 25.3819687, 55.0632345, 55.0530241,
55.0900183, 59.0649666, 31.8637152 s`，累计 `368.9736735 s`，ceil 后为
`369 s`，小于 profile 的 `max_total_julia_seconds=600`。5 个
`human_interruption` 记录的实际时长比其 55/59 s deadline 多约 0.053–0.090 s，
但仍低于 60 s stop-loss；这说明记录与“约 55/59 s 外部截止”一致，不证明严格
在 deadline 瞬间 kill。

manifest 的分类计数 `2 completed + 5 human_interruption + 1 program_exception`
与 8 条 run 一致。stdout/stderr 均保留，空 stderr 的 SHA-256 也一致。由于没有
保存 supervisor command、kill receipt、PID birth/termination receipt，60 s 外部
stop-loss 只能判为**记录声明得到时间区间支持，缺少独立执行证明**；所有中断结果
必须按 timeout-like/deferred/not-executed 处理，绝不能当作 valid。

## Capture hash 漂移

profile manifest 明确记录 probe capture 为 12,812 bytes、SHA-256
`F01F480007814BE6504F4C7DC7FCC36039C2F7A4FB1751E9D6B680C0BB33FB88`，当前 probe
为 12,817 bytes、SHA-256
`7EA02E3D4EA313CDCE5723150674A4C8B1440CB846FAA3189535397471E56522`，且
`rerun=false`。因此 raw 是 capture 版本的证据，不能与当前 probe source 混称为
同一 revision。最小处置是保留两种 hash，说明精确差异，并只重跑受影响的
`rules_parts`/rewrite-set bounded probe；在此之前不作 rewrite-set 或 saturation
结论。

另一个记录缺陷是 `measurements.json` 的 runs 计数：raw 支持 include/upstream/warm
各 **8** 次，catalog/RHS 各 **4** 次；文件写成 `5/5/5/3/3`。min/max 数值本身
与 raw 相符，但该计数使统计 receipt 不可直接作为审计汇总，应由记录维护者更正
或另行生成校正 manifest，不能回写 raw。

## 实现前最小边界

### P0

- 在单次 derivation 内为 immutable typed-AST program、rule、condition 和 receipt
  fragment 缓存 sealed bytes/hash；复用到 request hash、proposal key、trace、
  replay、payload/hash/validation。不得引入全局可变 registry，也不得改变 canonical
  bytes 或 tie-break 语义。
- 在进入 rewrite-set/saturation 前做保守 projected-cost/preflight（至少包含
  `n!`、rule count、projected members、canonical byte size）；超界必须返回现有
  `terminal_deferred`。保持冻结 `n=8`、`R=2`、`screen_only`，不以扩大上限换取
  通过。

### P1

- 将 proposal/member/visited 的内部查找改为 sealed-key deterministic map，最终
  emission 仍按现有排序和 witness tie-break；不得移除条件、provenance、identity
  或 fail-closed 检查。
- 增加可复核的 supervisor receipt：实际 command、startup/history flags、PID、UTC
  start/end、deadline、kill/exit code、stdout/stderr bytes/hash，并把 timeout 与
  harness program_exception 分开。修正 `measurements` 的 stage run counts。
- 在修复 probe 后，以单 Julia 进程、≤60 s/probe、≤600 s 累计的 bounded lane，
  先取得 rewrite-set receipt，再按预算测 saturation，最后才测 query/replay/
  validate。所有未产生 receipt 的阶段继续标为 `not_measured`。

## 复核边界

本文件不授予 UP5-01、B00/B04、R01-R10、L4、provider/physical/search 或 parent-goal
credit；不把局部 stage、文档、exit 记录或静态 factorial 结论升级为物理、工程或
全链路完成。
