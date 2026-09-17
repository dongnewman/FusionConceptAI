# AD-38 UP2 compile/discretization gap audit — independent review R3

结论：`pass_limited`。repair R2 已关闭 R2 的 F04/F05，且此前 R1 的 API、PhysicsCompilerV5 产品边界、DAG、AD-36 sidecar 和 credit ceiling 没有漂移。本结论只接受 AD-38 的静态 readiness/architecture work-order boundary；不接受任何 UP2 machine node、T0/T1/T2 authority、mesh/provider/solver/physical execution 或 R credit。

## 核验范围与执行边界

本轮只读核对原 AD-38 audit、repair R1/R2、AD-36 scope、当前 `task_manifest.json`、RuntimeV4 field APIs、G2/T0/T0-authority-recheck/parent-baseline 相关源码。HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`，当前 task manifest 为 39 tasks、schema `v4-upgrade-plan-20260914.1`、更新时间 `2026-09-15`。没有运行 Julia、DESC、重型 Python、provider、mesh、solver 或 replay；没有修改被审文件、源码、测试、core、旧 receipts、runs 或其他 agent 的 dirty paths。

## repair R2 已验证通过

### UP2-02/03/04 blockers 与 fresh gates

R2 已把原审计的逐阶段 machine blockers 恢复到 `dependency_chain_blockers[*].blocked_on`，并明确它们不属于已经存在的 `read_only_inputs`：

- UP2-02 同时等待 accepted UP2-01 EquationIR/WeakResidualIR/lowering receipt、fresh candidate-bound G2 mesh authority、chart/metric/embedding/region/interface/exterior ownership、mesh/basis/quadrature/face identity 与 assembly provenance、fresh AD-29 environment receipt。
- UP2-03 同时等待 accepted UP2-02 closed discrete receipt、candidate-bound G1 conservation accounts/occurrences、G3 return/exterior authority、applicable exterior provider admission/execution receipt、fresh AD-29 environment receipt。
- UP2-04 同时等待 accepted UP2-03 transfer/exterior receipt、discrete residual/Jacobian sparsity/block graph、solver capability manifest、consistent initial state 与 gauge/nullspace/algebraic constraints、fresh provider/backend 和 AD-29 environment receipts、independent fresh replay identity join。

每一阶段都有 `typed_absence_policy` 和 `execution_forbidden_when_typed_absent=true`。缺 authority、closed input、provider、environment 或 replay 时只能 `terminal_deferred`，不能进入 mesh/provider/transfer/exterior/coupled solver/numerical/physical execution。这满足用户要求的 typed absence no-execution boundary。

### 三条 field API 的真实路径、hash、公开 API 与 ceiling

repair R2 的 bytes/SHA 与当前 checkout 逐项匹配：

- `FieldProgramEvaluation.jl`: 44975 bytes，`97320caec8a8b759a4f3195b6fe5c4f1f3b2aed5370c98657cead70c94e24a86`。`FieldGridSpecV4`、`FieldEvaluationPlanV4`、`FieldEvaluationResultV4`、`FieldEvaluationReportV4` 和对应 compile/evaluate/manifest/execute 入口均存在；`FusionRuntimeV4.jl` 对外导出这些入口。sealed operator table 只执行基本代数与 `DOT`，GRAD/DIV_OP/CURL/LAPLACE/DT、multi-chart、periodic、time-dependent、non-scalar root 仍 deferred。
- `FieldResidualPipeline.jl`: 45405 bytes，`f928607e232e5667b27e3dc82365a376a93de830c36ec47ce2d2e767e9159856`。mission/binding/plan/receipt/report/store/manufactured receipt 类型及 compile/provider/execute/validate/convergence 入口均存在并由 `FusionRuntimeV4` 导出；其范围仍是 fixed/manufactured `LAPLACE(u)-2f` screen/deferred pipeline。
- `FieldResidualNumerics.jl`: 26849 bytes，`ed956e72e0d1f3c27d029ed1f463ce4fd38c3a9eb309c9ba9cc9ed735af2ccb5`。structured protocol、diagonal affine geometry、linear form、payload、assembly、solve 类型和对应入口均存在并由 `FusionRuntimeV4` 导出；其范围仍是 fixed structured affine/manufactured numerical slice，不能作为通用 G2 mesh、topology、provider 或 coupled solver authority。

三条路径均已加入 R2 `protected_read_only`，且没有被改写成 EquationIR、WeakResidualIR、DiscreteResidual、SolverPlan 或 physical evidence。

### 原 R1 API、PhysicsCompilerV5、DAG 与 AD-36 边界未漂移

R1 的 `RegionalMHDWeakResidualV4`、`AlgebraicResidualPlanV4`、Compiler、Spatial、Coupling、DiffusionProvider API hash 仍与当前 checkout 一致；它们仍分别受 screen/manufactured/deferred、zero-dimensional screen、fixed spatial、contract/provider-gap ceiling 约束。PhysicsCompilerV5 的 future product scope 仍是 9 个精确产品路径，当前均不存在，不构成伪实现；R2 没有扩大该 scope。

AD-36 sidecars 仍只允许位于 task-owned `archive/**` 或命名的 `review/**`/`status_sync_*/**`，不计入 exact product count；source/test/fixture/staticQA/launcher 混入 sidecar 仍 `scope_violation/fail_closed`。原 machine chain 仍为：

`UP1-04A-VNEXT-T2 → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01 → UP2-02 → UP2-03 → UP2-04`。

实际边与 R2 断言一致；T1 仍同时依赖 T0 与 T0 authority recheck，T2 仍依赖 T1。T0 authority recheck 仍只能 typed absent/terminal deferred/fail closed，不能由 fixture、synthetic/ref-only authority、legacy actual、default registry bridge 或历史 receipt 晋升。R2 的所有 UP2/provider/mesh/numerical/engineering/physical/B00/B04/R01–R10 credits 均为 false。

## 证据上限与复核建议

建议根接受 AD-38 仅作为 `pass_limited` 的静态审计/work-order boundary，并保留 `review_pending=true`、`accepted=false`；随后如需实现，仍须按当前 machine DAG 串行派发，并在每个阶段重新取得 candidate-bound authority、provider/backend/environment、输入输出哈希和独立 receipt。当前不得创建 PhysicsCompilerV5 产品文件、UP2 execution launcher、checked-present T0/T1/T2 authority 或任何 mesh/provider/physical artifact。

本复核不授予 UP2、B01/B02/B04/B05/B06/B08/B11、B00/B04、provider、mesh、solver、engineering、physical、search 或 R01–R10 credit。

