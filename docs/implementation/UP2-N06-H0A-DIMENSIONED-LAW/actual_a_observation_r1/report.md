# H0-A actual-A observation R1

日期：2026-09-15  
仓库：`D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD：`4b69f55f7f80240147a65a22809dc1207824dde2`  
范围：一次串行 actual-A 软件观测；不接受 H0-A actual authority、UP2 或物理能力。

## 执行路径

输入冻结在 [input_hashes.json](input_hashes.json)。诊断脚本先执行正式 runner
`test/GenomeV5/UP2/run_n06_dimensioned_law.jl` 的 loader/include 前缀：
`load_genome_v5_up2_components!()`，随后 include
`src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl`。actual package 使用正式 fixture
路径 `test/GenomeV5/UP1-04/layer_fixture_child.jl`，分别构造 G1/G2/G3，再调用
`integrate_genome_v5`、`up2_candidate_physical_binding_from_a` 和
`n06_h0a_bind_actual_a`。

诊断脚本没有 include `n06_dimensioned_law_tests.jl`，因此没有把 N06 的
`@testset` 或断言作为输出来源。`layer_fixture_child.jl` 是现有 G1/G2/G3
fixture/oracle helper；它在三个串行 child Julia 中加载对应层测试 fixture 并序列化
层对象，child 的 Test Summary 被保留在 [stdout.txt](stdout.txt)，但没有执行 N06
套件。顶层诊断只启动一次，且没有 Julia/DESC/provider/mesh/物理求解命令。

## 实际结果

结构化结果见 [result.json](result.json)，原始输出见 [stdout.txt](stdout.txt) 和
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

这说明当前 source projection 能从真实 G1/G2/G3 fixture 构造并进入
`n06_h0a_bind_actual_a`，但候选仍缺 candidate-owned dimensioned law / external
source authority。typed absence 与 gaps 是生产函数返回值，不是测试断言推导。

## 进程与原始收据

收据见 [run.json](run.json)、[output_hashes.json](output_hashes.json)、
[process_before.json](process_before.json)、[process_after.json](process_after.json)、
[dirty_before.txt](dirty_before.txt) 和 [dirty_after.txt](dirty_after.txt)。顶层 PID
为 `18040`，UTC `2026-09-15T00:38:18.561405+00:00` 至
`2026-09-15T00:39:29.303955+00:00`，stdout 1576 bytes、stderr 0 bytes，原始
stdout SHA256 为
`6e2b35df298b3004f43fd195b72bdd52db588d6a629b05e7d5c7cf1f55265ca0`，stderr SHA256
为 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

诊断进程已结束，结果文件完整且 stderr 为空，收据中的 exit code 为 `0`。启动
包装器在等待阶段因 PowerShell 保留变量 `$PID` 命名冲突中断，随后接管同一 PID
完成收据恢复；没有重新运行 Julia。脏状态从 305 行变为 306 行，增量是本次新
observation 目录；前后 Julia/DESC 进程快照均为空。

## 证据边界

本记录只接受一次 actual-A source-path 软件行为观察：`terminal_deferred`、typed
absence、source-derived gaps 和零 compile/provider/solver counters。它不接受
actual authority、完整 N06 dimensioned law、UP2 total、B00/B04、provider、mesh、
DESC、engineering、physical 或 R01–R10。后续必须由不同 Luna 独立复核本目录的
脚本、输入哈希、原始字节和结构化结果；不得把本次 fixture observation 当作真实
物理执行或终局通过。

