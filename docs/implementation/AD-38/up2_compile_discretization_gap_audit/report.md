# AD-38: UP2 compile/discretization gap audit

审计范围：三层 Genome V5 declaration 之后的 `UP2-01 → UP2-02 → UP2-03 → UP2-04`，重点是 typed declaration → semantic AST/lowering、G2 chart/metric/mesh/basis/quadrature/face ownership、topology transfer/exterior closure，以及 coupled solve/constraint residual/solver receipt。

审计方式：只读检查当前 `AGENTS.md`、v4 总纲与 `00/01/02/05/10/11/13/14/16/18`、`task_manifest.json`、当前 G1/G2/G3 V1 declarations、T0 transport、T0 authority recheck、parent baseline scaffold、RuntimeV4 compiler/field/spatial/coupling source/test/docs/runs。没有修改 core/source/test，没有运行 Julia/DESC/Python heavy/provider/mesh/solver，也没有把静态文档、fixture、局部测试或旧 receipt 升格为 UP2/R credit。

## 1. 当前结论与证据边界

当前正式状态仍是：三张 `UP2-01-G1/G2/G3-*` declaration preparation 为 `planned / proposal / accepted=false / review_pending`；`UP2-01` 至 `UP2-04` 均 `planned`，没有 execution dispatch。`UP2-00` 总门仍未接受，正式 50 条 B04 receipts、checker 和 two-process replay 仍待新鲜候选链完成。

现有 V1 文件确实保存了可供后续 typed lowering 消费的语义字段，但它们是 contract-only preparation：

| 层/对象 | 当前可复用语义 | 当前 ceiling 与未决项 |
|---|---|---|
| G1 `G1DiffusionDeclarationV1` | candidate-owned `u/K(x)/f`；typed `GRAD → K_APPLY → DIV`；单位、正定 K、残差符号 `-1`、closure/applicability refs、source/declaration hash | `g1_diffusion_receipt_v1` 固定 `proposal, accepted=false, terminal_deferred`，compile/provider/mesh/solver=0；没有 equation IR、weak form 或 operator executor |
| G2 `G2MBDeclarationV1` | bounded affine chart、Jacobian、`JᵀJ` metric/正定性、orientation/area/volume、Q1/Q2 mesh plan、quadrature points/weights、六面 face value/owner/orientation、unit algebra | mesh `execution_status` 仅 `declared/not_executed`；authority 缺失仍 `terminal_deferred`；没有实际 mesh cells、basis DOF、face quadrature assembly 或 backend receipt |
| G3 `G3SFDeclarationV1` | source/field/return/heat endpoints、方向/符号/单位/owner scope、rational conservative split、ledger closure、G1/G2 feedback target 与 authority projection | `g3_sf_admit_v1` 保持 proposal/false；同候选 authority/feedback/child 仍 deferred；没有 source provider、field return、thermal/engineering feedback executor |
| T0 `VNextDeclarationTransportV1` | 完整 G1/G2/G3 body/hash、G2 candidate envelope、四轴 provenance、G3 child typed-absent、bundle hash、contradiction `fail_closed` | 当前没有可独立读取的 fresh G2 mapping evidence receipt；G3 source content hash 与 realization/control/binding child 均 typed absent/`terminal_deferred`；T0 machine node `accepted=false` |
| T0 recheck | exact one-per-layer pairing、legacy projection 仅 contradiction check、fresh T0-owned authority 才能 checked-present、failure byte atomicity | 当前只输出 typed-absent/fail-closed；不存在 checked-present authority，所以 T1 blocked |
| parent baseline | G1/G2 present binding 需 source-backed declaration factory/locator/raw bytes/semantic hash/fresh review；缺失时只构造 typed absence | 当前没有 source-backed V1 instance/factory receipt；不能写 present parent/child，也不能 CAS promotion |

因此，当前三层 declaration 的 `present` 只能表示 typed declaration body 在源码中存在；在 fresh same-candidate T0 authority、T1 `CandidateStatePackageV5Next`、T2 identity rebinding 和独立复核之前，任何 UP2 输入都必须显式携带 `typed_absent/terminal_deferred`。不能把 G1/G2/G3 fixture、V1 declaration hash、legacy `actual`、ref-only adapter、`bridge_ready` 或旧 candidate receipt 当作物理输入或 provider authority。

当前 Genome/T1 gate 的关键未决证据：

1. 三层源文件 SHA 与 T0 preparation 记录一致（G1 `14d26e...dbf1a`、G2 `261516...8f61`、G3 `70b045...750d0`），但这是源文件 identity，不是 fresh candidate authority。
2. T0 的显式 gap 包括 `G2_candidate_mapping:terminal_deferred`、轴外部 receipt verification pending、`G3_source_content_hash:typed_absent:terminal_deferred`、三个 G3 child typed absent，以及 G3 upstream/feedback authority gaps。
3. recheck 只允许 fresh T0-owned declaration ref/hash/canonical bytes/source receipt/trusted attestation 输出 checked-present；当前无此输入，故只能 typed absent。parent baseline 同样只保留 absent state。
4. AD-30 的正式链仍为 `UP1-04A + G1/G2/G3 → T0 → T0-AUTHORITY-RECHECK → T1 → T2 → UP1-04A-VNEXT → UP2-00`。T1 的新 package/integrator 必须先成立，T2 才能重建 E0/G-I1A/E1/E2/UP2 identities；完成 T2 也不授予 provider/mesh/physical credit。

## 2. 现有实现的真实可复用 API

### 2.1 编译、AST 与 lowering 前缀

可复用的现有入口是 `src/RuntimeV4/Compiler.jl` 的 `compile_candidate`、`derive_capability_obligations` 和 `_runtime_validate_compiled_prefix`。它能校验候选/mission/bounds/grammar hash、保留四张 typed graph、收集 region/interface/boundary，并输出 `CompiledCandidatePrefixV4` 的 unresolved obligations。它不能生成 equation IR、weak residual、discrete residual、sparsity 或 solver plan。

`_runtime_edge_obligation` 只确认端口、同一空间维度、时间语义和单根 operator；非零空间会留下 `required_coordinate_declaration`，随后只产生 `required_physical_capability:<operator>`。源码明确说明 generic G2/G3 graph 不能证明 coordinate/metric/boundary closure 或 solver ABI。它可以作为 identity-preserving prefix validator 和 unresolved obligation carrier，不能作为 UP2-01 compiler。

`FieldProgramEvaluation.jl` 的 `compile_field_evaluation_plan`、`evaluate_field_program`、`compile_solver_input`、`field_evaluation_provider` 是 screen-level G2 field path。实际 evaluator 只执行 `IDENTITY/ADD/SUB/NEG/SCALAR_MUL/SCALAR_DIV/DOT`；`GRAD/DIV_OP/CURL/LAPLACE/DT`、multi-chart/chart transition/periodic/time-dependent/non-scalar root 都进入 deferred gap，且计划明确带 `g2_metric_unexecuted`。这可复用为 chart/metric provenance、solver-input hash 和 deferred classification，不能冒充 derivative lowering 或 PDE assembly。

`FieldResidualPipeline.jl` 的 `compile_field_residual_plan`、`compile_linear_field_residual_form`、`assemble_field_residual_kernel`、`solve_field_residual_kernel` 是有限 manufactured control。它强制 exact `LAPLACE(u)-2f` AST、unitless `u/f`、固定 structured affine geometry，并将 evidence class 记为 `manufactured_control` / `screen_only`。可以复用 source/boundary content hash、candidate-bound solver input/receipt/integrity checks和失败分类；不能复用 exact AST guard、固定 formula 或 `structured_field_residual_solve` 作为 variable-coefficient/aniso/multi-field UP2 compiler。

### 2.2 G2 空间、离散与现有 spatial slice

可复用的声明级函数是 `g2mb_chart_map`、`g2mb_chart_jacobian`、`g2mb_metric`、`g2mb_metric_positive_definite`、`g2mb_physical_oriented_area_vector`、`g2mb_volume_measure`、`g2mb_unit_algebra_errors` 和 `g2mb_admit`。它们能提供 exact rational chart/metric/normal/unit checks，适合作为 G2 declaration validator 与 future mesh input recipe。

不能复用为 UP2-02 的部分：`G2MBMeshPlanV1` 只有 cells/basis/quadrature declarations，未生成 physical cell coordinates、connectivity、DOF ordering、element/face local blocks、Jacobian provenance、interface trace 或 assembled global map；`g2mb_admit` 把 mesh execution 保持在 `declared`/`not_executed`。

`SpatialMultiRegionV4.jl` 的 `spatial_multiregion_declaration_v4`、`build_spatial_mesh_v4`、`spatial_basis_v4`、`assemble_spatial_system_v4`、`solve_spatial_state_v4` 可作为旧兼容 slice 的算法/receipt 参考：它有 Q1 结构网格、cell/face ownership、稀疏 Jacobian、row block/scale、attempt/iteration artifacts 和 solver exit。其真实范围仍是固定两 region、四状态 `B_R/B_phi/B_Z/p`、固定 ideal static MHD/interface/exterior/flux scenario，代码含固定 count/declaration guards；它不是 chart/metric/mesh declaration-driven general backend。

### 2.3 拓扑、外域、coupling 与 provider

`MultiRegionCouplingContracts.jl` 的 `MultiRegionRefV4`、`MultiRegionInterfaceV4`、`MultiRegionFluxBindingV4`、`MultiRegionCouplingContractV4` 和 `validate_multiregion_coupling` 能检查 region/interface/channel/edge/port/ledger/unit/orientation ownership，并保持 candidate prefix/hash binding。它是 screen-only coupling contract，不提供 transfer operator、exterior closure、discrete flux projection 或 solve。

`MultiRegionDiffusionProvider.jl` 中 `integrate_multiregion_context` 明确总是加入 `required_real_multiregion_constitutive_provider` gap；`admit_desc_multiregion_provider` 即使收到 validated DESC fixed-boundary receipt，也保留 `desc_fixed_boundary_output_is_not_multiregion_closure`、constitutive-field 和 interface-flux gaps。文件后半的 `DiffusionRegionSpecV4`/`MultiRegionCouplingPlanV4`/`solve_multiregion_diffusion` 是 standalone 1-D、恰好两个 region、uniform mesh、scalar diffusion prototype；不是 G1/G2/G3 general coupling provider。

现有 spatial runs 提供的是 numerical/physical boundary evidence，不是可移植 implementation credit：W24 child 的 wrapper exit=0 但 physics solver exit=4 (`iteration_limit`)，四个 case 未收敛、`conservation=false`、physical `unsupported/deferred`，credible count=0；paired audit 还发现 source-set/hash mismatch。它们不能被重标为 UP2 pass，也不能成为新 Genome 的 fresh receipt。

## 3. 分阶段静态就绪缺口

### UP2-01 — equation compiler / semantic lowering

**真实输入。** 必须是完成 T2/UP2-00 前置链的新候选 `CandidateStatePackageV5Next` 或其冻结 candidate-bound equivalent；包括 G1/G2/G3 complete semantic bodies、operator/closure registry、四轴、source/declaration/bundle/package hashes、G3 child/feedback state、mission/bounds/applicability 与 provider capability manifest。当前 G1/G2/G3 V1 declaration 可作 schema fixture/typed declaration source，不能直接作为 current candidate authority。

**缺口。** 当前 Compiler 没有 `EquationIR/WeakResidualIR/DiscreteResidual/SolverPlan` 类型；没有 typed AST → operator semantic lowering、strong→weak 分部积分符号、function-space/domain binding、term unit closure、time/multi-field operator expansion、boundary/interface obligation ownership 或 nullspace record。G1 V1 的 `GRAD/K_APPLY/DIV` 只是 declaration records，未绑定 G2 chart/metric/function space，也未被 runtime operator executor 消费。固定 FRP exact AST 不能替代通用 lowering。

**未来 work-order 文件归属（拟议，实施前冻结）。** UP2-01 只拥有：

- `src/RuntimeV4/EquationIRV4.jl`
- `src/RuntimeV4/WeakResidualIRV4.jl`
- `src/RuntimeV4/PhysicsCompilerV5.jl`
- `test/runtime_v4_equation_ir_v5_tests.jl`
- `test/runtime_v4_weak_residual_v5_tests.jl`
- `docs/implementation/UP2-01/`（README、manifest、acceptance、receipts）

不得改旧 `Compiler.jl` 语义、旧 FRP exact fixture、`default_operator_registry()`、旧 V4 evidence 或 T0/T1/T2 文件；如需窄调用 seam，应另由 integration owner 审查后 additive 接入。

**输出。** Candidate-bound Equation IR、WeakResidual IR、closure/boundary/unit/nullspace obligations、operator capability route、compiler receipt 与 unresolved classification。每个 term 要保留 gene refs、function spaces、chart/ref、units、time semantics、conservation account；没有执行器/closure/authority 时只能 `terminal_deferred`，结构冲突 `fail_closed`。

**依赖与 exit gates。** 依赖 T2/UP2-00 新身份链、UP1-04 完成以及 fresh environment receipt。最小 gate 是：一个不等于 LAPLACE fixture 的 variable-coefficient declaration 可独立 lowering；系数/边界/单位/AST order/label erase 改变或保持对应 hash；缺 closure/coordinate/operator executor 返回具体 deferred；pure Neumann/gauge 产生显式 nullspace 而不是删方程；错误单位、负 K、重复 boundary、未声明 source 负控 fail closed。compile-only pass 不授 mesh/provider/numerical/physical credit。

### UP2-02 — chart/metric → mesh/basis/quadrature/assembly

**真实输入。** UP2-01 Equation/WeakResidual IR；T2-bound G2 chart/metric/embedding/region/interface/exterior declaration；cells、basis、quadrature、face orientation/value/ownership、material field、unit/scale recipe；provider manifest 与 environment receipt。当前 G2MB chart/metric exact values只能作为 declaration-level source，mesh plan 当前仍 not executed。

**缺口。** 没有由 chart/metric 生成可复现 mesh topology、physical coordinates、DOF ordering、basis gradients、per-element determinant/metric pullback、face quadrature and outward normal/value ownership、interface double trace、local-to-global assembly map、residual/Jacobian block/unit/scale/provenance。现有 spatial mesh 是固定 two-region/Q1；现有 field evaluator 只采样 screen values；没有 generic candidate-input entry。

**未来 work-order 文件归属（拟议，实施前冻结）。** UP2-02 只拥有：

- `src/RuntimeV4/DiscreteResidualV4.jl`
- `src/RuntimeV4/FieldMeshAssemblyV5.jl`
- `src/RuntimeV4/CandidateInputEntryV5.jl`
- `test/runtime_v4_discrete_residual_v5_tests.jl`
- `test/runtime_v4_mesh_assembly_v5_tests.jl`
- `test/runtime_v4_candidate_input_entry_v5_tests.jl`
- `docs/implementation/UP2-02/`（README、manifest、acceptance、receipts）

`SpatialMultiRegionV4.jl` 和旧 mesh artifacts 只读；不得以替换 `_smr_declaration` guard 的方式宣称 general entry 已完成，guard 与真实 execution support 必须同批交付。

**输出。** DiscreteResidual（mesh/basis/quadrature/DOF/element-face maps、assembled sparse structure、interface transfer hooks）、mesh/assembly receipt、candidate/input hashes、MMS/reference payload and checker hooks。

**依赖与 exit gates。** 依赖 UP2-01 pass-limited compile contract、fresh G2 mesh/provider authority 和 fresh environment receipt。至少一项留出声明要在同一入口改变 coefficient/boundary/region connection 而不改源码；三层 nested mesh 上冻结 MMS solution error、residual、integral conservation、mesh/time refinement gates 分别通过；boundary ownership/orientation、unit/metric determinant 与 duplicate/missing face negative controls fail closed。mesh declaration 或 local assembly pass 仍不授 provider/physical credit。

### UP2-03 — topology transfer / exterior closure

**真实输入。** UP2-02 discrete mesh/assembly；G1 conservation accounts/occurrences；G2 region/interface conditions；G3 source/return/heat/ledger law、external region and circuit return declarations；transfer/interpolation policy、divB/positivity/gauge constraints、far-field truncation and applicability bounds。当前 G3 law 有 ledger contract，但没有 runtime source/return path；当前 DESC bridge 不能提供 multiregion interface flux/constitutive closure。

**缺口。** 没有 remesh/split/merge conservative projection、field constraint preservation (`divB`, positivity, gauge)、interface trace transfer with sign/normal/unit closure、physical topology event model 与 static design edit separation、真空/导体/remote boundary/exterior path、source/circuit return closure。现有 `validate_multiregion_coupling` 只查 declaration ownership/port/ledger, 不执行 transfer；fixed-boundary DESC output 明确缺 multiregion closure。

**未来 work-order 文件归属（拟议，实施前冻结）。** UP2-03 只拥有：

- `src/RuntimeV4/TopologyTransferV4.jl`
- `src/RuntimeV4/ExteriorClosureV4.jl`
- `test/runtime_v4_topology_transfer_v4_tests.jl`
- `test/runtime_v4_exterior_closure_v4_tests.jl`
- `docs/implementation/UP2-03/`（README、manifest、acceptance、receipts）

不得把 `SpatialGeometryEditV4.jl` 的 numerical remap 或旧 W24 geometry edit 当作 physical topology event；不得以 `default_operator_registry()` 增加桥接 operator 代替 source-backed external provider。

**输出。** Candidate-bound transfer/exterior plans、conservative mapping and defect receipts、interface/exterior closure obligations、far-field sensitivity inputs、topology classification (`design_edit` vs `physical_event`) 与 fail/deferred diagnostics。

**依赖与 exit gates。** 依赖 UP2-02 discrete receipt、G1/G3 exact account/return closure、真实 applicable exterior provider manifest 和 fresh environment receipt。transfer 前后总量差须在预注册容差，local field constraints 与 error gate 同时满足；far-field truncation/exterior mesh refinement sensitivity 通过；删除 exterior、漏 return 或 wrong orientation/flux sign 的 negative controls 必须 fail/deferred。数值 remapping pass 不授 physical topology credit。

### UP2-04 — coupled solve / constraints / integration

**真实输入。** UP2-03 transfer/exterior plans；discrete residual/Jacobian sparsity and block graph；typed G1/G2/G3 ports and dependency graph；consistent initial state; gauge/nullspace and algebraic constraints; solver capability manifest (Newton/Krylov/ODE-DAE/preconditioner/globalization); candidate/input/provider/backend/environment hashes。

**缺口。** 没有 generic strong-coupled block/DAE assembly or candidate-bound solver plan. Existing spatial Newton-like path is fixed MHD and its diagnostics are useful receipt shape only. Existing standalone diffusion solve is 1-D two-region and uses direct sparse solve; it does not consume Equation/Weak/Discrete IR, G3 ports, dynamic feedback, transfer, or exterior closure. No generic initial-consistency check, constraint direction/nullspace API, monolithic residual, coupled convergence receipt, provider identity join, or execute-once/fresh-replay distinction for the new candidate.

**未来 work-order 文件归属（拟议，实施前冻结）。** UP2-04 只拥有：

- `src/RuntimeV4/CoupledSolvePlanV4.jl`
- `src/RuntimeV4/CandidateCoupledEntryV4.jl`
- `test/runtime_v4_coupled_solve_plan_v4_tests.jl`
- `test/runtime_v4_candidate_coupled_entry_v4_tests.jl`
- `scripts/run_v4_candidate_coupled_v5.jl`
- `docs/implementation/UP2-04/`（README、manifest、acceptance、receipts）

集成者独占公共入口和 runner；UP2-04 不修改旧 `src/FusionConceptAI.jl` loader、旧 candidate entry、旧 registry 或历史 run receipts，除非未来独立 integration work order 明确冻结 additive seam。禁止 ref-only authority 和 default-registry bridge。

**输出。** SolverPlan（block/DAE graph、constraint/nullspace/initial consistency、algorithm/preconditioner/tolerances/stopping/restart）、coupled residual/Jacobian and conservation receipt、candidate-bound provider/backend/environment identity、real exit/failed classification and replay artifacts。

**依赖与 exit gates。** 依赖 UP2-03 transfer/exterior receipt、fresh provider capability and environment receipt。强耦合 residual、constraint residual、transfer defect、conservation must pass simultaneously; sequential post-processing is insufficient. Deliberate wrong Jacobian, missing/inconsistent initial value, stagnation, singular/nullspace and wrong constraint orientation must produce exact diagnostic classes. `solver_exit=0` alone is insufficient; numerical failure, program exception, provider gap, physical failure and not-executed must remain separate.

## 4. 证据分类与当前可派遣范围

| 证据层 | 当前真实证据 | 可支持的最高判断 | 当前不能支持 |
|---|---|---|---|
| contract/schema | G1/G2/G3 V1 constructors/validators/fixtures；T0/recheck/baseline typed-absent scaffolds；UP2 precompiler mutation validators | typed field shape、hash/identity checks、negative classification、explicit gap | current candidate authority、UP2 acceptance、B04、provider/mesh/solver/physical |
| compile | RuntimeV4 prefix compiler；FRP exact manufactured compiler | prefix obligations、screen-only fixture receipt、candidate/hash integrity | Equation/Weak/Discrete/SolverPlan general lowering |
| mesh/discretization | G2 declaration-level chart/metric/mesh plan；旧 W24 fixed Q1 spatial artifacts | declaration constraints和旧 fixture algorithm reference | new G2 mesh execution、basis/DOF/quadrature/assembly receipt |
| provider | `integrate_multiregion_context`/DESC admission explicit provider/closure gaps | recoverable provider-gap classification | real 3-D constitutive/source/return/exterior provider |
| numerical | W24 solver exit 4/iteration limit；old fixed spatial diagnostics；standalone 1-D diffusion prototype | historical bounded numerical failure/diagnostic shape | new candidate UP2 convergence or all-grammar failure |
| physical | W24 physical `unsupported/deferred`, no physical validation, credible count 0 | current absence/deferred boundary | physical pass、engineering、R01–R10、R credit |

当前只能继续做：三层 declaration/T0/T1/T2 的静态合同审查、future file ownership freeze、JSON/link/diff/cleanup static validation、typed absent/deferred planning。不能派遣 UP2 mesh/provider/solver/physical execution，不能声称 UP2 或 R credit，不能用 current Genome declarations 直接构造 physical subject。

## 5. fresh environment receipt gate

在任一新候选的 UP2-01 provider-adjacent compile、UP2-02 mesh、UP2-03 exterior/provider、UP2-04 coupled solve 或 related replay 之前，必须按 AD-29 重新取得 candidate-bound fresh receipt：

- candidate/source/input identity and hashes；interpreter executable path + SHA256；module path + SHA256；完整 dependency versions/build/channel metadata and hashes；
- FreeGS inherited base packages、VMEX external tree identity/digest、Pleiades external tree identity/digest、CQL3D C/Fortran/NetCDF/HDF5 toolchain identity；
- exact command/cwd/PID or in-process/start/end UTC/exit/stdout/stderr/combined raw hashes/output-artifact hashes；profile, applicability limitation and classification；
- fresh candidate/package/provider/backend hash joins；历史 receipt 仅保留原环境/原输入范围，不能自动 promotion。

若缺环境 capability，应输出具体 provider gap + `terminal_deferred`；不能通过重装标签、模块存在、`bridge_ready` 或旧 receipt 清除缺口。DESC fixed-boundary Windows profile 的 JAX/finufft 缺失仍是 unsupported/terminal-deferred capability，安装完成本身也不产生 provider evidence。

## 6. 审计结论

当前 RuntimeV4 与 GenomeV5 可复用的是 identity-preserving contracts、screen obligations、fixed manufactured/spatial receipt shapes 和 explicit failure taxonomy。UP2-01→04 的核心执行链尚未存在：没有 declaration-driven semantic compiler、通用 chart-to-mesh assembly、topology/exterior closure 或 candidate-bound coupled SolverPlan。由于 T0 authority recheck 和 parent baseline 当前 typed-absent，T1/T2 尚未就绪；因此三层 Genome 在 UP2 入口必须以 typed declaration + explicit absent/deferred gaps 处理，不能派任何物理执行。

本报告是静态 implementation-readiness audit；不修改 core/source/test，不运行 heavy/provider/mesh/solver，不授予 UP2、B01/B02/B04/B05/B06/B08/B11、provider、mesh、engineering、physical、B00/B04 或 R01–R10 credit。
