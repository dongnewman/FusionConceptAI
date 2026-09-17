# H0-A actual-A source-path observation acceptance R1

状态：**`accepted_limited`，仅限一次 actual-A candidate-bound source-path 软件观测**。
H0-A 总门仍为 **`accepted=false`**。

本记录接受 R2 的独立复核结论 `pass_limited`，并保留 R1 收据 erratum 与 R2
完整运行档案：

- [R1 receipt erratum R2](actual_a_observation_r1/receipt_erratum_r2/report.md)
- [R2 observation](actual_a_observation_r2/report.md)
- [R2 run.json](actual_a_observation_r2/run.json)（完整 OS command args 唯一来源）
- [independent actual-A R2 review](independent_actual_observation_r2/report.md)

## Observed software evidence

R2 在同一冻结 source/test/fixture/runner 输入上，通过正式 loader、N06 source
include 和 G1/G2/G3 fixture path 进入 `n06_h0a_bind_actual_a`，得到：

- `status=terminal_deferred`；declaration type 为
  `FusionConceptAI.N06H0ATypedAbsentV1`，`declaration_is_nothing=false`；
- `gap_code=external_ref_required`；三个 gaps 为
  `g1_endpoint_provenance_missing`、`external_ref_required:g1-loss:G1`、
  `external_ref_required:g2-thermal:G2`；`errors=[]`；
- `compile_calls/provider_calls/solver_calls=0/0/0`；candidate hash 与 E0
  package hash 为 `0cfe748c66121a69bf818778a92a6bce1f14bf2892f4159326c426bbc1c3a16a`，
  E0 bound-input hash 为 `5dc008c66d37f7f810f08ea3b30f8eafd6ca7e5fda2f128a6dd2525e2ff4cd97`；
- R2 PID `55732`，exit `0`；原始 stdout/stderr、进程和 dirty 快照均见 R2
  目录，完整 OS 参数只认 `run.json`。

该结果只证明当前软件 source path 返回 typed deferred/absence 分类；它不证明
candidate-owned dimensioned law 或 external authority 存在。

## Acceptance ceiling

本有限接受不授予 actual authority、H0-A total、UP2、B00、B04、provider、mesh、
DESC、engineering、physical 或 R01–R10 信用。既有
[software precursor acceptance](software_precursor_acceptance_r1.md)、总
[acceptance boundary](acceptance.md)、旧 R6/R7/R8 收据、核心索引、源码、测试和
fixture 均保持不变。R1 OS provenance uncertain 由 erratum 保留，R2 的独立
`WaitForExit` 收据只支持 R2。

