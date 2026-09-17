# AD-38 UP2 compile/discretization gap audit — independent review R2

结论：`changes_requested`。repair R1 已实质关闭 independent R1 的 F01–F03：真实 specialized RuntimeV4 API 已盘点，UP2-01 `PhysicsCompilerV5` 的 source/test/fixture/staticQA/docs 产品集合和 AD-36 evidence-only sidecars 已明确，machine DAG 也与当前 `task_manifest.json` 的边匹配。仍有两处窄缺口阻止我把 repair R1 记为 `pass_limited`：R1 的 machine-readable chain 没有保留原审计中 UP2-02/03/04 的 fresh authority/provider/environment 和输入闭合 blockers；`read_only_inputs` 也遗漏了原审计已经核对的 field-evaluation/manufactured-residual supporting APIs。修复只需增补 R1 文档/manifest，不需要改源码或执行。

## 核验边界

本轮只读了原 AD-38 audit、`repair_r1/revised_report.md`、`repair_r1/manifest.json`、AD-36 scope、当前 `task_manifest.json` 和现有 RuntimeV4/G2/T0/T1 源码。HEAD 为 `4b69f55f7f80240147a65a22809dc1207824dde2`，task manifest schema 为 `v4-upgrade-plan-20260914.1`，更新时间 `2026-09-15`，任务数 39。没有运行 Julia、DESC、provider、mesh、solver 或重型 Python，没有修改源码、测试、core、旧 audit 或旧证据；没有授予 UP2/R/physical credit。

## 已确认通过的修复项

### API、hash 与 screen/deferred 边界

repair R1 的六个 API inventory 路径与当前 checkout 的字节数/SHA-256 全部匹配：

- `RegionalMHDWeakResidualV4.jl` 21337 bytes，`d925718c0165b3e2563d61459365953f1cc516713f87b5601cd6a46f158d632d`；
- `AlgebraicResidual.jl` 35593 bytes，`7979cd8b2512958644f896116a284f3d6e352eb9e72e50e21193079af87f621f`；
- `Compiler.jl` 14428 bytes，`7a550e2b9ac27693f7e7008f3562ef6d5f52795997bc89c676440cb2e4bab4aa`；
- `SpatialMultiRegionV4.jl` 56867 bytes，`cac5b47beeee2fbab7de6f171f7f155ff5534bc51edec0e66ee8caf711d6b932`；
- `MultiRegionCouplingContracts.jl` 12019 bytes，`2fed6f0a575c031e0e984a6dbabd9e872b1417c1da71a446ca98e1fba60eb398`；
- `MultiRegionDiffusionProvider.jl` 19060 bytes，`9daacfaf47ea9031290ccf57ff31e24c8458b79f15fa43cae9e2eb596f41a7b5`。

R1 对两个此前遗漏的 specialized slice 的边界判断准确：`RegionalMHDWeakResidualV4` 仍有 weak ledger 但缺 test-function weak integral、boundary trace 和 residual Jacobian，执行结果保持 `:deferred`/`screen_only`；`AlgebraicResidualPlanV4` 只覆盖零维白名单代数约束，不能冒充 PDE/mesh/coupled SolverPlan。Compiler、固定 spatial、coupling contract、DESC/1-D diffusion prototype 的 screen/fixed/deferred ceiling 也与源码一致。

### PhysicsCompilerV5 产品和 AD-36 sidecars

R1 已把未来 UP2-01 的 exact product scope 写全为 9 个路径：`EquationIRV4.jl`、`WeakResidualIRV4.jl`、`PhysicsCompilerV5.jl`、专属 contract test、JSON fixture、static QA、README、acceptance 和 manifest。产品路径当前均不存在，符合“未来 work-order proposed ownership”而不是伪造实现的边界。

R1 还明确了 AD-36 sidecars 只能位于 task-owned `docs/implementation/UP2-01/archive/**` 或命名的 `review/**`/`status_sync_*/**`，不计入 exact product count，且 source/test/fixture/staticQA/launcher 混入 sidecar 必须 `scope_violation/fail_closed`。这与 AD-36 当前 `review_pending/accepted=false` 的 evidence-only contract 一致。

### 当前 DAG、T0/T1 gate 和状态上限

R1 的八条链边与当前 machine manifest 逐条匹配：

`UP1-04A-VNEXT-T2 → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01 → UP2-02 → UP2-03 → UP2-04`。

当前 T2、aggregate、UP2-00、T0、T0 authority recheck、T1、UP2-01…04 均未形成 accepted execution gate；T1 的真实依赖仍是 T0 与 T0 authority recheck 双闸门，T2 依赖 T1。T0 authority recheck 只能输出 typed absence/terminal deferred/fail closed，不能通过 fixture、synthetic/ref-only authority、legacy actual、default registry bridge 或历史 receipt 晋升。R1 对 read-only inputs 与 blocked_on 的字段分离方式正确，所有 provider/mesh/numerical/physical/B00/B04/R01–R10 credits 保持 false。

## 必须修复的窄问题

### F04 — 后续 stage 的 machine blockers 比原 audit 窄，fresh receipt gate 没有逐阶段保留

原 AD-38 manifest 的 stage gates 明确要求：

- UP2-02 必须同时等待 fresh G2 mesh authority、fresh environment receipt、UP2-01 compile contract；
- UP2-03 必须等待 G1 conservation accounts、G3 return/exterior authority、applicable exterior provider 与 fresh environment receipt；
- UP2-04 必须等待 discrete residual、solver capability manifest、consistent initial state、fresh provider/environment receipt 和 replay。

repair R1 的 machine-readable `dependency_chain[*].blocked_on` 只留下了较短的摘要：UP2-02 的 mesh/basis/quadrature/boundary ownership、UP2-03 的 transfer/exterior/orientation、UP2-04 的 coupled residual/constraint/solver receipt。R1 文本没有把上述原审计的 per-stage candidate-bound fresh receipt/provider/initial-state blockers 完整恢复到机器字段。请在 R1 manifest（并在 revised report 中保持同一表述）补齐这些项，并继续将它们放在 `blocked_on`，不能放入只读输入或把缺失能力写成已创建的 machine node。typed absence/terminal deferred 下，UP2-02/03/04 仍不得进入 mesh/provider/solver/physical execution。

### F05 — 原审计已通过的 field-evaluation/manufactured-residual supporting API 未进入 repair R1 的 exact read-only inventory

原 audit 明确核对过 `src/RuntimeV4/FieldProgramEvaluation.jl`、`src/RuntimeV4/FieldResidualPipeline.jl` 和其数值 supporting slice `src/RuntimeV4/FieldResidualNumerics.jl`，并以此支撑“GRAD/DIV_OP/CURL/LAPLACE/DT deferred”和固定 `LAPLACE(u)-2f` manufactured screen 的复用边界。repair R1 的 API inventory/read_only_inputs 没有保留这三条路径及 hash；这会让 repair 的“exact APIs/paths/hashes”记录比原 audit 窄，且可能让 future UP2-01 作者遗漏保护的 fixed/manufactured slice。

请补回三条路径及当前 hash：FieldProgramEvaluation `44975` bytes / `97320caec8a8b759a4f3195b6fe5c4f1f3b2aed5370c98657cead70c94e24a86`；FieldResidualPipeline `45405` bytes / `f928607e232e5667b27e3dc82365a376a93de830c36ec47ce2d2e767e9159856`；FieldResidualNumerics `26849` bytes / `ed956e72e0d1f3c27d029ed1f463ce4fd38c3a9eb309c9ba9cc9ed735af2ccb5`。它们的 ceiling 仍是 fixed/manufactured/screen/deferred，不增加任何 UP2 或 physical credit。

## 退出门

完成 F04–F05 后可重新进行独立 R3 复核。当前应保持 repair R1 与本复核 `review_pending=true`、`accepted=false`、`changes_requested`；不应创建 PhysicsCompilerV5 产品文件、machine UP2 child、T0 checked-present authority 或任何 launcher。AD-36 sidecars、T0/T1 双闸门、fresh environment receipt、default-registry/ref-only 禁止和所有 UP2/R/physical credits 必须继续保持原边界。

