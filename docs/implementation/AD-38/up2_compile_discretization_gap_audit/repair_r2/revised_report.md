# AD-38 UP2 compile/discretization readiness audit — repair R2

状态：`changes_requested`；本轮只新增本目录的 `revised_report.md` 与 `manifest.json`，修复 independent R2 的 F04/F05。旧 audit、repair R1、core/source/test、Genome 与历史 receipt 均保持只读；没有运行 Julia、DESC、重型 Python、provider、mesh 或 solver。

## F04：逐阶段 machine blocker 恢复

当前 manifest 链仍是：

`UP1-04A-VNEXT-T2 → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01 → UP2-02 → UP2-03 → UP2-04`。

本链的边与 `docs/v4_multitopology_generation/task_manifest.json` 一致；下游节点仍未获得执行接受。T0 authority recheck 仍只能输出 `typed_absent` / `terminal_deferred` / `fail_closed`，T1 仍要求 T0 与 authority-recheck 双闸门，T2 仍依赖 T1。任何下游 typed absence 都是阻断条件，不得被改写成 execution-ready。

UP2-02 的 machine `blocked_on` 必须同时包含：

- accepted `UP2-01` compile contract，以及 candidate-bound EquationIR/WeakResidualIR/lowering receipt；
- fresh candidate-bound G2 mesh authority，至少覆盖 chart/metric/embedding、region/interface/exterior ownership、mesh/basis/quadrature/face declarations 与可核验的 mesh identity；
- fresh AD-29 candidate-bound environment receipt，含 interpreter/module/dependency/backend identity 与 command/exit/hash receipt；
- 任一上述能力为 typed absent、authority 未 checked-present 或 receipt 过期时，保持 `terminal_deferred`，不得进入 mesh/provider/physical execution。

UP2-03 的 machine `blocked_on` 必须同时包含：

- accepted UP2-02 discrete mesh/assembly receipt；
- candidate-bound G1 conservation accounts/occurrences 与可重算的 conservation ledger；
- candidate-bound G3 return/exterior authority，含 source/return/heat/ledger law 与 applicable exterior region/closure；
- applicable exterior provider manifest 及其 fresh provider admission/execution receipt；
- fresh AD-29 environment receipt；
- 任一 G1/G3/exterior/provider/environment 字段为 typed absent 或 `terminal_deferred` 时，保持 `terminal_deferred`，不得执行 transfer、exterior provider 或 physical closure。

UP2-04 的 machine `blocked_on` 必须同时包含：

- accepted UP2-03 transfer/exterior closure receipt；
- candidate-bound discrete residual/Jacobian sparsity and block graph；
- solver capability manifest（算法、preconditioner、globalization、tolerances、stopping/restart 及适用性）；
- consistent initial state，以及 gauge/nullspace/algebraic constraint admission；
- fresh candidate-bound provider/backend receipt 与 fresh AD-29 environment receipt；
- independent fresh replay，含 input/provider/environment identity join；
- 任一 discrete residual、solver capability、initial state、provider/environment 或 replay 字段为 typed absent/`terminal_deferred` 时，保持 `terminal_deferred`，不得进入 coupled solver、numerical execution 或 physical claim。

这些项属于 `blocked_on`，不属于“已经存在的输入”。`read_only_inputs` 只列静态检查过的路径和历史 bounded slice，不清除任何 blocker。

## F05：Field RuntimeV4 三条 supporting API 的当前只读 inventory

下表的 bytes/SHA-256 是本次在当前 checkout 重新计算的结果，与 independent R2 给出的值逐项相等。三条路径加入本 repair 的 protected read-only inventory。它们提供 specialized fixed/manufactured/screen/deferred slice，不能升格为通用 EquationIR、WeakResidualIR、DiscreteResidual、SolverPlan、provider authority 或 physical evidence。

| path | bytes | current SHA-256 | public types / functions | ceiling |
|---|---:|---|---|---|
| `src/RuntimeV4/FieldProgramEvaluation.jl` | 44975 | `97320CAEC8A8B759A4F3195B6FE5C4F1F3B2AED5370C98657CEAD70C94E24A86` | `FieldGridSpecV4`, `FieldEvaluationPlanV4`, `FieldEvaluationResultV4`, `FieldEvaluationReportV4`; `compile_field_evaluation_plan`, `evaluate_field_program`, `field_evaluation_manifest`, `execute_field_evaluation` | fixed chart/sampling screen and deferred classification；manufactured 不适用；不执行 `GRAD/DIV_OP/CURL/LAPLACE/DT`、multi-chart、periodic、time-dependent 或 non-scalar general lowering |
| `src/RuntimeV4/FieldResidualPipeline.jl` | 45405 | `F928607E232E5667B27E3DC82365A376A93DE830C36EC47CE2D2E767E9159856` | `StaticFieldResidualMissionV4`, `TypedFieldSourceScaleBindingV4`, `FieldResidualPipelinePlanV4`, `FieldResidualPipelineReceiptV4`, `FieldResidualPipelineReportV4`, `FieldResidualPipelineStoreV4`, `ManufacturedFieldConvergenceReceiptV4`; `compile_field_residual_plan`, `field_residual_provider`, `execute_once!`, `validate_field_residual_pipeline_report`, `build_manufactured_field_convergence_receipt`, `validate_manufactured_field_convergence_receipt` | fixed/manufactured `LAPLACE(u)-2f` pipeline、screen receipt、deferred/provider-gap classification；不是 variable-coefficient/aniso/multi-field production compiler |
| `src/RuntimeV4/FieldResidualNumerics.jl` | 26849 | `ED956E72E0D1F3C27D029ED1F463CE4FD38C3A9EB309C9BA9CC9ED735AF2CCB5` | `StructuredGridProtocolV4`, `DiagonalAffineChartGeometryV4`, `LinearFieldResidualFormV4`, `FieldResidualPayloadV4`, `ResidualAssemblyV4`, `FieldSolveResultV4`; `field_residual_numerics_source_hash`, `compile_diagonal_affine_geometry`, `compile_linear_field_residual_form`, `assemble_field_residual_kernel`, `solve_field_residual_kernel` | fixed structured affine/second-order/LAPLACE manufactured numerical slice；screen/deferred and bounded numerical diagnostics；不提供 general G2 mesh, topology, provider or physical authority |

`FieldProgramEvaluation.jl` 的 sealed operator table只执行 `IDENTITY/ADD/SUB/NEG/SCALAR_MUL/SCALAR_DIV/DOT`；`GRAD/DIV_OP/CURL/LAPLACE/DT` 明确进入 deferred。`FieldResidualPipeline.jl` 对 G2 artifact 与 manufactured form 做 candidate/hash/integrity checks，但其 exact static formula 和 `structured_field_residual_solve` 仍是 manufactured control。`FieldResidualNumerics.jl` 使用 uniform structured grid、diagonal affine chart 和 direct sparse LU；这些 receipts 可作为 shape/integrity 参考，不能代替 UP2-02 的 candidate-bound G2 mesh authority 或 UP2-04 的 coupled solver receipt。

## Protected read-only inputs

本轮静态 inventory 的 protected paths 包括三条 F05 API 及 repair R1 已核对的 compiler/spatial/coupling/provider API：

- `src/RuntimeV4/FieldProgramEvaluation.jl`
- `src/RuntimeV4/FieldResidualPipeline.jl`
- `src/RuntimeV4/FieldResidualNumerics.jl`
- `src/RuntimeV4/Compiler.jl`
- `src/RuntimeV4/RegionalMHDWeakResidualV4.jl`
- `src/RuntimeV4/AlgebraicResidual.jl`
- `src/RuntimeV4/SpatialMultiRegionV4.jl`
- `src/RuntimeV4/MultiRegionCouplingContracts.jl`
- `src/RuntimeV4/MultiRegionDiffusionProvider.jl`
- `docs/v4_multitopology_generation/task_manifest.json`
- `docs/implementation/AD-29/`
- `docs/implementation/AD-36/`
- `docs/implementation/AD-38/up2_compile_discretization_gap_audit/report.md`
- `docs/implementation/AD-38/up2_compile_discretization_gap_audit/manifest.json`
- `docs/implementation/AD-38/up2_compile_discretization_gap_audit/cleanup_inventory.md`
- `docs/implementation/AD-38/up2_compile_discretization_gap_audit/repair_r1/revised_report.md`
- `docs/implementation/AD-38/up2_compile_discretization_gap_audit/repair_r1/manifest.json`

这些是 read-only evidence inputs，不是 future product ownership。不得改动 `default_operator_registry()`、旧 V4 loader、旧 fixtures/receipts、历史 runs 或任何 other-agent dirty path。

## Unchanged boundaries

UP2-01 的 PhysicsCompilerV5 exact product scope、AD-36 evidence-only sidecar规则、当前 machine DAG、T0 authority recheck/T1 dual gate、`read_only_inputs` 与 `blocked_on` 分离，以及所有 provider/mesh/numerical/physical/B00/B04/R01–R10 credits 均保持 repair R1 的边界。AD-36 sidecars 仍只能位于 task-owned `archive/**` 或命名 `review/**`/`status_sync_*/**`，不能藏入 source/test/fixture/staticQA/launcher 或借 sidecar 规避 exact scope。

本修复只恢复审计精度：三条 specialized API 仍是 fixed/manufactured/screen/deferred ceiling；UP2-02/03/04 在 typed absence、缺 fresh authority、缺 fresh provider/environment receipt、缺 closed input 或缺 replay 时仍只能 deferred，不能派遣物理执行，不能声称 UP2 或 R credit。
