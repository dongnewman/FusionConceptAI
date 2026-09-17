# H0-A actual-A observation R2

日期：2026-09-15  
仓库：`D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
结论：R2 OS 收据完整；结果仍为 `terminal_deferred`。本记录不接受 actual
authority、UP2 或物理能力。

## 执行与输入

R2 使用与 R1 完全相同的已审诊断脚本：
`actual_a_observation_r1/actual_a_observation_r1.jl`，并复制 R1 的
`input_hashes.json`，其 SHA256 为
`3d0c18e50c9bd0f45b60298aab0ef72ec846bece185c23cf4d6d1e69f92d479a`。输入冻结
文件包括 N06 生产源、N06 测试/fixture/runner、正式 G1/G2/G3 fixture helper
及其层 fixture；R2 运行前逐项比对均匹配 R1 哈希。

脚本仍先调用 `load_genome_v5_up2_components!()`，再 include N06 生产源，并经
`test/GenomeV5/UP1-04/layer_fixture_child.jl` 构造实际 G1/G2/G3 package。它没有
include N06 测试套件，未使用断言产生观测字段。三个 layer child 仅加载既有
fixture/oracle 文件并序列化层对象；其 Test Summary 原样保存在 stdout。

## R2 结果

结构化结果见 [result.json](result.json)，原始字节见 [stdout.txt](stdout.txt) 和
[stderr.txt](stderr.txt)：

| 字段 | 观测值 |
|---|---|
| `status` | `terminal_deferred` |
| `declaration` | `FusionConceptAI.N06H0ATypedAbsentV1`，`nothing=false` |
| `gap_code` | `external_ref_required` |
| `errors` | `()` |
| `gaps` | `g1_endpoint_provenance_missing`; `external_ref_required:g1-loss:G1`; `external_ref_required:g2-thermal:G2` |
| `compile/provider/solver_calls` | `0 / 0 / 0` |
| candidate hash | `0cfe748c66121a69bf818778a92a6bce1f14bf2892f4159326c426bbc1c3a16a` |
| E0 bound-input hash | `5dc008c66d37f7f810f08ea3b30f8eafd6ca7e5fda2f128a6dd2525e2ff4cd97` |

R1/R2 结果字段与 candidate/E0 identity 一致。typed absence 和 gaps 来自生产
`n06_h0a_bind_actual_a` 返回值；它们表明当前 candidate 仍缺 dimensioned law
及外部 source authority，不能解释为物理失败或物理通过。

## OS、原始字节与脏状态

完整运行收据见 [run.json](run.json)，进程快照见
[process_before.json](process_before.json)、[process_launch.json](process_launch.json)、
[process_after.json](process_after.json)，字节清单见
[output_hashes.json](output_hashes.json)。R2 使用非保留变量 `$childPid` 和
`$processHandle.WaitForExit()`，PID `55732`，真实 exit `0`；UTC
`2026-09-15T01:01:39.6139442Z` 至 `2026-09-15T01:02:56.3173059Z`。启动前
Get-CimInstance 无 Julia/DESC，启动时记录了 `julia.exe` identity，结束后快照
仍无 Julia/DESC。

stdout 为 1580 bytes，SHA256
`59919c2358623477645b0fa1b85f83a2b527c43f900d757517a268482471efd6`；stderr 为
0 bytes，完整 SHA256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。dirty 快照
前后均 306 行，SHA256 均为
`4391b518d16631943a0153e828b1994daa328c400d3ef460078458fb00816411`；R2 没有新增
生产/测试/fixture/core 修改。R1 的 PID/exit 不确定性由
`actual_a_observation_r1/receipt_erratum_r2/` append-only 记录，R2 不覆盖 R1。

## 证据边界与后续复核

R2 只支持一次 candidate-bound source-path 软件观察：typed
`terminal_deferred`、typed absent、source-derived gaps 和零执行计数。不同 Luna
仍需独立复核脚本、冻结输入、result/raw bytes、process identity 和 OS exit 收据。
本记录不授予 actual authority、H0-A total、UP2、B00/B04、provider、mesh、DESC、
engineering、physical 或 R01–R10 信用。

