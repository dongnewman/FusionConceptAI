# H0-A actual-A observation R2 independent review

结论：`pass_limited`；`accepted=false`；`review_pending=true`。本复核只接受一次 candidate-bound source-path 软件观察，不接受 actual authority、H0-A total、UP2、B00/B04、provider、mesh、DESC、engineering、physical 或 R01–R10 信用。本复核为只读检查，没有运行 Julia、DESC、provider、mesh、solver 或 physics，也没有覆盖任何既有证据。

## R1 erratum 与 R2 输入

R1 的 `receipt_erratum_r2` 是 append-only，正确修复了原 manifest 中截断的空 stderr SHA-256，并把 305→306 的 dirty 增量归因改为并发的 `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/`；它同时明确 R1 PID/exit 的 OS provenance 仍为 uncertain。R2 没有重新解释或覆盖 R1。

R2 使用同一份已冻结的 `actual_a_observation_r1.jl`，输出到 R2 自己的 `result.json`。R2 的 `input_hashes.json` 与 R1 原文逐字相同，文件 SHA-256 为 `3d0c18e50c9bd0f45b60298aab0ef72ec846bece185c23cf4d6d1e69f92d479a`；其中四个主输入及其余 G1/G2/G3 fixture 依赖均在当前 checkout 逐项重算匹配。四个主输入为：N06 source `c317ce62e8ec1252491bfbf195daccda6ba05cc2a847bcfd311f391916cc8d1d`（59,585 bytes）、N06 test `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8`（48,902 bytes）、N06 fixture `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`（1,451 bytes）和正式 runner `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`（299 bytes）。HEAD `4b69f55f7f80240147a65a22809dc1207824dde2` 匹配。

诊断脚本的路径合同仍然清楚：调用 `load_genome_v5_up2_components!()` 一次，include N06 生产源一次，使用 `test/GenomeV5/UP1-04/layer_fixture_child.jl` 各构造一个 G1、G2、G3 child fixture，并且没有 include N06 测试套件。三次 child 调用是 fixture 序列化所需的子 Julia 进程；`top_level_julia_runs=1` 对观察驱动器成立。

## 结果与字节证据

R2 `result.json` 为 1,623 bytes，SHA-256 `1b092b02aa4656291c46e734e9b536bf81fb4ab7892cf1ec2c4ed31c22b5bdd0`，与 `output_hashes.json` 和 R1 结果字节一致。结果字段为：`status=terminal_deferred`；`declaration=FusionConceptAI.N06H0ATypedAbsentV1` 且 `declaration_is_nothing=false`；`declaration_gap_code=external_ref_required`；`errors=[]`；gaps 恰为 `g1_endpoint_provenance_missing`、`external_ref_required:g1-loss:G1`、`external_ref_required:g2-thermal:G2`；`compile_calls/provider_calls/solver_calls=0/0/0`。candidate hash 与 E0 package hash 均为 `0cfe748c66121a69bf818778a92a6bce1f14bf2892f4159326c426bbc1c3a16a`，E0 bound-input hash 为 `5dc008c66d37f7f810f08ea3b30f8eafd6ca7e5fda2f128a6dd2525e2ff4cd97`。

R2 原始 stdout 为 1,580 bytes，SHA-256 `59919c2358623477645b0fa1b85f83a2b527c43f900d757517a268482471efd6`；stderr 为 0 bytes，完整 SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。`output_hashes.json` 中 stdout、stderr、result、dirty、process、input 和诊断脚本的所有记录均与实际字节匹配，清单自身 SHA-256 为 `719937de24265f055dda26a9b9eb7d42c0ca672885ceabe4a7af5a1874c421a3`。

## R2 进程、退出与脏状态

R2 运行收据 `run.json`（SHA-256 `adead66ce4d3bc9b778b79921dbf469cf67936f85730e8e1eaed0d8c09b64649`）记录：使用 task-specific `$childPid`，调用 `$processHandle.WaitForExit()`，PID `55732`，exit `0`，UTC `2026-09-15T01:01:39.6139442Z` 至 `2026-09-15T01:02:56.3173059Z`。`process_launch.json`（235 bytes，SHA-256 `51452ca636fc8e4d41e4371adc90beaec9b22d1910210266a82a8c86ebae8393`）观察到同一 PID、`julia.exe`、父 PID `42440`，创建时间 `2026-09-15T09:01:39.652803+08:00`，与 UTC 起始时间一致；前后 process 快照均为空，且各自 3 bytes、SHA-256 `37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570`。这足以把 R2 的 PID 与 Julia 进程及一次真实 WaitForExit 过程绑定到本次运行。

进程启动快照中的 `command_line` 只保留了 Julia 可执行文件路径，完整参数由同一 `run.json` 的 command 字段记录；因此它证明了 executable identity，但不是独立的带参数 OS command-line 快照。这个限制不改变 R2 的 `pass_limited`，但应在更高等级执行收据中继续保留完整 command-line 观测。

R2 dirty 前后均为 306 行，两个文件均为 15,148 bytes、SHA-256 `4391b518d16631943a0153e828b1994daa328c400d3ef460078458fb00816411`，逐字相同；没有发现 R2 运行造成的生产、测试、fixture 或核心目录残留。R2 证据目录自身属于既有未跟踪 implementation 父目录，不能用 porcelain 子行数单独推断其创建时刻。

## 证据边界

R2 的真实软件行为只支持：loader/source-path 可进入 `n06_h0a_bind_actual_a`，并返回 typed `terminal_deferred`、typed absence、三个 source-derived gaps 和零执行计数。它不证明 dimensioned law 已具备 candidate-owned external authority，也不证明任何 provider、mesh、DESC、工程或物理能力。R1 的 OS 不确定性仍由其 erratum 保留；R2 的完整 WaitForExit 收据不能回溯提升 R1。

