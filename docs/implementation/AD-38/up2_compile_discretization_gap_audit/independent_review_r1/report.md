# AD-38 UP2 compile/discretization gap audit — independent review R1

结论：`changes_requested`。AD-38 的主结论、证据上限和禁止执行边界基本成立；但当前审计没有完整盘点两个已经存在且容易被误读为通用 UP2 能力的 RuntimeV4 slice，也没有把 UP2-01 的 compiler 测试归属和机器依赖与拟议工作单对齐到可直接派单的程度。因此本审查不接受该 audit 作为最终 work-order freeze。修复只需增补审计文档/manifest，不需要改源码或运行。

## 核验范围与不变边界

我在现有 HEAD `4b69f55f7f80240147a65a22809dc1207824dde2` 上只读核对了 AD-38 的 `report.md`、`manifest.json`、`cleanup_inventory.md`，当前 `task_manifest.json` 的 UP2-01…04 条目，RuntimeV4/G2/T0/T0-authority-recheck/parent-baseline 的真实源码。未运行 Julia、DESC、provider、mesh、solver 或重型 Python；未改被审文件。当前进程快照没有 Julia/DESC；已有 Python 进程保持不动。审计声明的三张 G1/G2/G3 source SHA 与工作区实际值一致：

- G1 `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a`；
- G2 `261516671151647bccb71f2fefd5f71cd2ed444f5eeba0bf90b29687d3a78f61`；
- G3 `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0`。

## 已通过的主判断

1. `Compiler.jl` 的 `compile_candidate`、`derive_capability_obligations` 和 `_runtime_validate_compiled_prefix` 是 identity-preserving prefix validator/obligation carrier；其实际输出没有 EquationIR、通用 WeakResidualIR、DiscreteResidual 或耦合 SolverPlan。`FieldProgramEvaluation.jl` 对 GRAD/DIV_OP/CURL/LAPLACE/DT、multi-chart、periodic、time-dependent 和非标量 root 保持 deferred；`FieldResidualPipeline.jl`/`FieldResidualNumerics.jl` 是固定 structured affine、unitless、manufactured `LAPLACE(u)-2f` screen slice。审计禁止把这些 slice 升格为 UP2 通用 compiler 或物理证据，判断正确。
2. G2 `G2MBMeshPlanV1` 的真实 `execution_status` 仍为 `:declared`/`:not_executed`；`g2mb_admit` 仍对 mesh execution 留 gap。chart/Jacobian/metric/area/volume、basis/quadrature/face owner 是 declaration-level input，不能替代 physical cells、DOF、local/global assembly、face trace 或 backend receipt。T0 的 G2 mapping 为 typed absent/terminal deferred，T0 authority recheck 没有 checked-present，parent baseline 只能构造 typed absence。因而 typed absence 必须继续禁止 mesh/provider/solver/physical dispatch，审计的 ceiling 正确。
3. `MultiRegionCouplingContracts.jl` 仍是 ownership/unit/orientation/candidate hash contract；`MultiRegionDiffusionProvider.jl` 仍明确真实 multiregion constitutive/interface/exterior provider gaps，后段的 two-region 1-D diffusion 仅 prototype。`SpatialMultiRegionV4.jl` 是固定 two-region/Q1/four-state static MHD slice。UP2-02/03/04 所需 chart-to-mesh、generic assembly、topology transfer、exterior/return closure、candidate-bound coupled SolverPlan 与 fresh replay 均未由这些 API 提供。
4. 拟议 UP2-01→UP2-04 的主要文件集合在层间无路径碰撞，依赖方向可形成 `T2 → UP2-00 → UP1-04 → UP2-01 → UP2-02 → UP2-03 → UP2-04` 的无环链；UP2-02/03/04 的输入、输出和 negative gates 覆盖 mesh/basis/face ownership、transfer/exterior、constraint/nullspace、provider/environment 和 `solver_exit=0` 不足等关键边界。fresh candidate/environment receipt、`default_operator_registry()` 不可作为 bridge、ref-only authority 不可晋升的限制也写得足够明确。
5. AD-38 原交付三文件的 SHA/路径范围、cleanup no-deletion 和全局 dirty 保护与工作区一致；其 `status=review_pending`、`accepted=false`、`claim_ceiling=contract_only` 没有误授 UP2/R credit。

## 必须修复的窄问题

### F01 — 真实的 specialized weak/algebraic slices 未列入复用边界

当前源码确实存在：

- `src/RuntimeV4/RegionalMHDWeakResidualV4.jl` 的 `RegionalMHDWeakResidualV4`、`assemble_regional_mhd_weak_residual` 和 `execute_regional_mhd_weak_residual`。它有 test/source/boundary ledger，但 `missing_capabilities` 固定包含 `:desc_test_function_weak_integral`、`:regional_residual_jacobian`、`:boundary_limit_trace`，状态保持 `:deferred`、`claim_ceiling=screen_only`，且不是 G1 variable-coefficient Equation/WeakResidual lowering。
- `src/RuntimeV4/AlgebraicResidual.jl` 的 `AlgebraicResidualPlanV4`、`compile_algebraic_residual_plan` 和 `solve_algebraic_residual`。它是零维约束子图 screen slice，只允许有限 algebraic operators，证据 ceiling 固定为 `screen_only`，不是 UP2 的 spatial/discrete/coupled `SolverPlan`。

AD-38 将“没有 weak form/solver plan”写成过宽的否定，且 `protected_read_only` 没列这两个实际 API（也没列其 `FieldResidualNumerics.jl` supporting slice）。这会让后续作者无法从审计中看到需要保留的 specialized screen boundary。请在 report/manifest 中明确改成“没有通用 EquationIR/WeakResidualIR/DiscreteResidual/SolverPlan；存在上述 specialized screen/deferred slices，均不可复用为 UP2 通用实现”，并把这三条 RuntimeV4 路径加入 protected read-only 和复用矩阵。不能因此授予任何 UP2/R credit。

### F02 — UP2-01 future ownership 缺少 compiler 专属测试文件

拟议文件列出了 `PhysicsCompilerV5.jl`，但只有 equation IR 与 weak residual 两个测试文件，没有明确的 `test/runtime_v4_physics_compiler_v5_tests.jl`（或等价专属测试归属）。UP2-01 的 gate 明确要求 variable-coefficient/非 LAPLACE lowering、unit/closure/nullspace、deferred/fail-closed 分类和 candidate/hash sensitivity；这些不能仅由两个 IR unit tests 隐含承担。请把 compiler 测试、其输入 fixture/receipt 的归属和静态负控写入 future file ownership；仍保持 shared loader/public entry 由 integration owner 单独处理。

### F03 — future stage gate 与现有 machine manifest 的 dependency 关系需显式冻结

当前 `task_manifest.json` 的机器条目是 `UP2-01.depends_on=["UP1-04"]`，而 AD-38 stage gate 写成 `UP2-01` 依赖 `UP1-04`、`T2`、`UP2-00`。这不是当前 DAG 的环：`T2 → UP1-04A-VNEXT → UP2-00 → UP1-04 → UP2-01` 已在 16 work order 中给出。但是 audit 必须明确这三项是 dispatch 前必须满足的传递/冻结前置，而不是已经写入 machine manifest 的新依赖；在没有同步冻结 exact task-manifest/work-order mutation 前不能派 UP2-01。对 UP2-02/03/04 同样标明 fresh authority/provider/environment 是 typed prerequisite，不要把字符串 gap 名称误当已创建 machine node。

## 结论与退出门

修复 F01–F03 后可重新提交独立复核；不要求改 `src/`、`test/`、shared entry、registry、旧 receipts 或 runs，也不要求运行任何 Julia/DESC。当前仍只能接受 static contract/readiness audit 的有限边界：`UP2-01..04` machine status 仍 `planned`，AD-38 仍 `review_pending/accepted=false`，T0/T1/T2/UP2-00 仍未解锁。typed-absent/terminal-deferred 继续禁止 provider/mesh/solver/physical execution；所有 UP2、B01/B02/B04/B05/B06/B08/B11、B00/B04、physical、engineering 和 R01–R10 credits 均为 false。

