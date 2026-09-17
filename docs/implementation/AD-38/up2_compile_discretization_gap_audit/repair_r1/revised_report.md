# AD-38 UP2 compile/discretization readiness audit — repair R1

状态：`changes_requested`；本轮只做静态、只读修复。没有修改 RuntimeV4/core/source/test，也没有运行 Julia、DESC、Python heavy、provider、mesh 或 solver。原始审计文件保持不变；本轮唯一新增文件是本目录的 `revised_report.md` 与 `manifest.json`。

本修复关闭 independent R1 的三项缺口：

1. 从当前 checkout 逐项绑定 `RegionalMHDWeakResidualV4`、`AlgebraicResidualPlanV4` 及 compiler/spatial/coupling/provider API 的真实路径、类型、函数和当前字节 SHA-256，并给出可复用边界。
2. 把 UP2-01 `PhysicsCompilerV5` 变成可审查的专属 product scope：source、contract test、fixture、staticQA、dedicated docs，以及 AD-36 evidence-only sidecars 的准确归属、输入/输出、负向路径和退出门。
3. 将 machine-readable dependency chain 与当前 `task_manifest.json` 逐项对齐，显式区分 `read_only_inputs` 与 `blocked_on`，并以本地 DAG 断言保留 T0 authority recheck/T1 双闸门。

## 1. 当前 authority 与结论

当前清单是 `docs/v4_multitopology_generation/task_manifest.json`，`base_head=4b69f55`，`updated_at=2026-09-15`，39-task 合同仍是 collaboration-contract-only。链条中的 T2、aggregate、UP2-00、UP1-04B、UP1-04、UP2-01、UP2-02、UP2-03、UP2-04 均为 `planned`；T2、aggregate、UP2-00 的 machine `accepted=false`，其余下游节点的 `accepted` 字段为 `null`，不能解释为接受。所有本审计记录的 stage/provider/mesh/numerical/engineering/physical/R01–R10/B00/B04 credits 都是 `false`。

T0 authority recheck 的 local scaffold 只有 `accepted_limited` 软件范围；machine node 仍为 `planned / proposal / review_pending / accepted=false`。它当前只能从无 fresh T0-owned declaration record 的输入产生 `typed_absent` 或 `fail_closed`。T1 仍然需要 **T0 与 authority recheck 两个依赖同时满足**；T2 还依赖 T1。现有 parent baseline 的 `accepted_limited` 也只接受局部 typed-absent/scaffold 软件合同，不能产生 present G1/G2 authority。因而任何 UP2-01 编译输入在这些记录变为 checked-present 之前，只能是 typed declaration absent/deferred；不得通过 fixture、legacy actual、ref-only adapter、synthetic authority、bridge 或 `default_operator_registry()` 绕过。

AD-29 允许 contract-only static planning，但在 UP2-01/provider/mesh/physical 或组合执行前仍要求 fresh candidate-bound environment receipt。历史 receipt 不能晋升当前可复现性；本审计不声称已经有 fresh receipt。

## 2. 当前可复用 API inventory（当前 checkout 字节哈希）

以下 hash 是本次静态读取时当前文件的 SHA-256，不是已经接受的产品 receipt。`screen`、`fixed`、`manufactured`、`deferred` 是复用上限；它们都不能充当 EquationIR、通用 compiled residual、mesh/provider evidence 或 physical authority。

### 2.1 Regional MHD weak ledger

文件 `src/RuntimeV4/RegionalMHDWeakResidualV4.jl`，SHA-256 `D925718C0165B3E2563D61459365953F1CC516713F87B5601CD6A46F158D632D`。

类型：`RegionalMHDTestFunctionV4`、`RegionalMHDSourceTermV4`、`RegionalMHDBoundaryTermV4`、`RegionalMHDUpstreamBindingV4`、`RegionalMHDWeakResidualV4`、`RegionalMHDWeakExecutionRequestV4`、`RegionalMHDWeakExecutionResultV4`、`RegionalMHDWeakExecutionReceiptV4`、`RegionalMHDProductionGapRequestV4`。关键函数：`RegionalMHDTestFunctionV4`、`RegionalMHDSourceTermV4`、`RegionalMHDBoundaryTermV4`、`assemble_regional_mhd_weak_residual`、`validate_regional_mhd_weak_residual`、`replay_regional_mhd_weak_residual`、`execute_regional_mhd_weak_residual`、`validate_regional_mhd_weak_execution`、`regional_mhd_weak_residual_manifest`、`make_regional_mhd_production_gap_request`、`validate_regional_mhd_production_gap_request`、`bind_regional_mhd_desc_production_gap`。

可复用：candidate/context/AST/hypergraph hash join、test/source/boundary typed ownership、strict opposite interface-pair ledger、independent replay、manufactured-control bookkeeping，以及 `screen_only` 的 deferred execution receipt。当前常量 `_RMWR_MISSING` 明确保留 `desc_test_function_weak_integral`、`regional_residual_jacobian`、`boundary_limit_trace` 三项缺口；execution result 固定 `status=:deferred`、`provider_executed=false`、`claim_ceiling=screen_only`。

不可复用：它没有 EquationIR schema、term-level semantic lowering、basis/quadrature assembly、compiled residual executor 或 physical provider。`test_only_desc_regional_observation_binding` 与 `test_only_static_mhd_interface_ledger_binding` 只能是 manufactured/test-only binding。`RegionalMHDProductionGapRequestV4` 只消费已有 q3/jump/global artifacts 后记录 gap；不能把这些 artifacts 变成 production weak form。

### 2.2 Algebraic residual plan

文件 `src/RuntimeV4/AlgebraicResidual.jl`（不是不存在的 `AlgebraicResidualPlanV4.jl`），SHA-256 `7979CD8B2512958644F896116A284F3D6E352EB9E72E50E21193079AF87F621F`。

类型：`StateValueV4`、`AlgebraicScenarioV4`、`AlgebraicResidualRowV4`、`AlgebraicResidualPlanV4`、`AlgebraicResidualCompilationV4`、`ExecutableAlgebraicSubjectV4`、`AlgebraicResidualResultV4`、`AlgebraicSliceReportV4`。关键函数：`compile_algebraic_residual_plan`、`evaluate_algebraic_residual`、`solve_algebraic_residual`、`algebraic_residual_manifest`、`execute_algebraic_once!`。

可复用：已闭合、零维、scalar-field、algebraic-time 的 constraint subgraph；固定白名单 AST（`IDENTITY/ADD/SUB/NEG/SCALAR_MUL/SCALAR_DIV`）；state bounds/unit checks；candidate-bound `plan_hash`；bounded Newton screen；typed `ProviderManifestV4`/`SolverInputV4`/`RuntimeEvidenceV4` join；缺口返回 `AlgebraicResidualCompilationV4(:deferred, nothing, gaps)`。这是目前最接近 typed AST→residual lowering 的 screen-only vertical slice。

不可复用：它只编译零维代数约束，不表达 PDE/weak terms、空间坐标、chart metric、basis、quadrature、interface/exterior topology、field mesh 或 coupled multi-physics. `solve_algebraic_residual` 的 `:converged` 只是在该零维 screen protocol 下的 numerical result，`claim_ceiling` 仍是 `screen_only`，不是 physical evidence 或 UP2 compiled residual。

### 2.3 Compiler

文件 `src/RuntimeV4/Compiler.jl`，SHA-256 `7A550E2B9AC27693F7E7008F3562EF6D5F52795997BC89C676440CB2E4BAB4AA`。

函数：`_runtime_decl_hash`、`_runtime_graph_node_descriptor`、`_runtime_program`、`_runtime_edge_ports`、`_runtime_root_operator`、`_runtime_type_token`、`_runtime_edge_obligation`、`_runtime_structural_obligation`、`_runtime_collect_declarations`、`compile_candidate`、`derive_capability_obligations`、`_runtime_validate_compiled_prefix`。

可复用：`CandidateStatePackageV4`/`GenomeContractRegistryV4` 的 typed graph declaration collection、candidate/payload/hash identity、port/dimension/time/single-root structural obligations 与 capability obligation listing。`compile_candidate` 的结果是 `CompiledCandidatePrefixV4`；它没有 equation term IR、weak lowering、discrete operator、mesh basis 或 solver receipt。

### 2.4 Spatial / mesh

文件 `src/RuntimeV4/SpatialMultiRegionV4.jl`，SHA-256 `CAC5B47BEEEE2FBAB7DE6F171F7F155FF5534BC51EDEC0E66EE8CAF711D6B932`。

类型/函数：`SpatialMultiRegionDeclarationV4`、`SpatialMeshV4`、`SpatialMultiRegionCaseV4`、`SpatialMultiRegionResultV4`、`spatial_multiregion_declaration_v4`、`build_spatial_mesh_v4`、`spatial_basis_v4`、`load_spatial_data_v4`、`spatial_field_v4`、`assemble_spatial_system_v4`、`solve_spatial_state_v4`、`execute_spatial_multiregion_v4`、`validate_spatial_result_v4`、`canonical_hash(::Union{SpatialMultiRegionCaseV4,SpatialMultiRegionResultV4})`。

可复用：固定两-region declaration/mesh/basis/scaled assembly 的 screen/fixed prototype；`_smr_declaration` 对固定 declaration hash 做 fail-closed 检查；`_smr_upstream` 做 candidate/context/provider receipt join；`SpatialMultiRegionResultV4` 保留 `physical_validation=:unsupported` 与 `claim_ceiling=screen_only`。

不可复用：当前没有 G2 chart metric/mesh basis/quadrature/boundary ownership 的通用 candidate-input pipeline，也没有 general discretized residual or physical validation。固定空间例程不能作为 UP2-02 的 G2 authority；历史数值失败不能被重标为 mesh readiness。

### 2.5 Coupling contract / provider

文件 `src/RuntimeV4/MultiRegionCouplingContracts.jl`，SHA-256 `2FED6F0A575C031E0E984A6DBABD9E872B1417C1DA71A446CA98E1FBA60EB398`。类型：`MultiRegionRefV4`、`MultiRegionInterfaceV4`、`MultiRegionFluxBindingV4`、`MultiRegionCouplingContractV4`、`MultiRegionCouplingValidationV4`。函数：各类型 constructors、`semantic_view`、`multiregion_coupling_contract`、`validate_multiregion_coupling`。可复用：region/interface/node/port/channel/unit/orientation/ledger identity contract 与 candidate hash validation。文件自身声明是 screen-only contract，不组装或求解 physical system。

文件 `src/RuntimeV4/MultiRegionDiffusionProvider.jl`，SHA-256 `9DAACFAF47EA9031290CCF57FF31E24C8458B79F15FA43CAE9E2EB596F41A7B5`。类型：`MultiRegionContextIntegrationV4`、`MultiRegionDESCAdmissionV4`、`DiffusionBoundaryV4`、`DiffusionRegionSpecV4`、`MultiRegionCouplingPlanV4`、`MultiRegionDiffusionResultV4`、`MultiRegionDiffusionReceiptV4`。函数：`integrate_multiregion_context`、`admit_desc_multiregion_provider`、`solve_multiregion_diffusion`、相关 `canonical_hash`/`semantic_view`/`_receipt` helpers。

可复用：context/provider receipt identity checks；DESC fixed-boundary admission that remains deferred where constitutive/closure fields are absent；standalone exactly-two-region, uniform-grid 1-D diffusion diagnostic. 不可复用：DESC fixed-boundary output is not multiregion closure；1-D direct sparse solve is not general UP2 coupling, topology transfer, exterior closure, constraint residual, or solver authority。

## 3. UP2-01 exact proposed product scope

UP2-01 只能在 chain predecessor `UP1-04` accepted and T0/T1/T2 authority gates satisfied后进入 implementation review。建议冻结以下 exact product/contract set；这些文件名是未来 work order 的 proposed ownership，不是当前存在的 source：

| category | proposed owned path | required role |
|---|---|---|
| source | `src/RuntimeV4/EquationIRV4.jl` | candidate-bound equation/term/closure/boundary semantic IR types and canonical hash |
| source | `src/RuntimeV4/WeakResidualIRV4.jl` | typed weak-term, test-space, interface/exterior and unresolved-capability records |
| source | `src/RuntimeV4/PhysicsCompilerV5.jl` | exact typed declaration → semantic AST → lowering → compiled weak residual boundary |
| contract test | `test/runtime_v4_physics_compiler_v5_contract_tests.jl` | positive identity/lowering and all registered negative classifications |
| fixture | `test/runtime_v4_physics_compiler_v5_fixture.json` | immutable input fixture only; cannot stand in for present authority |
| staticQA | `test/runtime_v4_physics_compiler_v5_static_qa.py` | source ownership, import/path, forbidden bridge/default-registry and exact-file checks |
| dedicated docs | `docs/implementation/UP2-01/README.md` | scope, API, evidence boundary, future handoff |
| dedicated docs | `docs/implementation/UP2-01/acceptance.md` | exit gates and claim ceiling |
| dedicated docs | `docs/implementation/UP2-01/manifest.json` | exact product list, hashes, receipts and status |

AD-36 sidecars are separate evidence-only outputs, excluded from exact product count and protected from cleanup. They must be task-owned and append-only under `docs/implementation/UP2-01/archive/**` (or named `review/**` / `status_sync_*/**` below that task directory), with proposed named records `archive/evidence_index.json`, `archive/command_receipts.json`, `archive/cleanup_inventory.md`, and `review/independent_review_r1.md`. Sidecars may contain raw stdout/stderr, exit/PID/UTC, interpreter identity, input/output/artifact hashes, repair/cleanup/review/status metadata only. A source, test, fixture, staticQA, launcher or product/contract deliverable placed there is `scope_violation` and `fail_closed`; no sidecar may be used to evade exact ownership.

Required inputs: the T2-bound candidate package and identity receipts; T0/T1 accepted G1/G2/G3 public declaration refs and hashes; operator/closure registry snapshot; typed time/coordinate/unit/boundary/applicability/capability declarations; and a fresh AD-29 environment receipt before any execution. Missing present G2/G3 authority remains typed absent/deferred.

Required outputs: candidate-bound `EquationIRV4` and `WeakResidualIRV4`; canonical term/source/test-space/interface/exterior ownership; lowering receipt with source AST hash, semantic IR hash, compiled residual hash and unresolved capability ledger; negative classification receipt; exact source/test/fixture/staticQA/docs hashes; and the AD-36 sidecar evidence index. Output must state that it is contract/compile evidence only.

Negative controls must prove: absent declaration/provider/coordinate/metric/function-space, unit/time/dimension mismatch, duplicate or missing boundary ownership, unclosed interface/exterior ledger, negative or non-finite coefficient, missing nullspace/gauge for pure Neumann, unknown operator/closure, label/family/id routing, changed coefficient input hash, label-erasure invariance, fixture/ref-only/synthetic authority, default registry mutation, and foreign candidate receipt. Missing capability is `terminal_deferred`; structural contradiction is `fail_closed`; an unexpected implementation fault is `program_exception`. No physical execution is an acceptable negative control.

Exit gates: dedicated source, contract test, fixture, staticQA and dedicated docs all exist and have exact hashes; fresh environment receipt is present before any executable follow-up; a non-fixture variable-coefficient combination lowers with candidate-bound identity; coefficient mutation changes input hash; labels do not change semantic result; independent checker does not share the implementation's row builder; no shared/default registry bridge is added; independent Luna review passes; provider/mesh/numerical/physical and R credits remain false.

## 4. Future work order scopes and blockers

`UP2-00` remains contract-only schema/validator/fixture/checker/invocation-count interface; it cannot write solver, mesh, provider or physical backend. `UP1-04B` remains the formal fixture/mutation/two-process replay gate. `UP1-04` remains the integration-owned V5 package/registry entry and candidate identity join. UP2-02 consumes an accepted PhysicsCompilerV5 output and owns general chart metric/mesh/basis/quadrature/boundary ownership plus candidate-input entry. UP2-03 consumes discrete residual and owns topology transfer/interface orientation/exterior closure. UP2-04 consumes closed discrete topology and owns coupled solve, constraint residual, solver receipt and final status classification. None may promote the fixed, algebraic, manufactured or standalone 1-D slices into physical authority.

For every stage, `read_only_inputs` means artifacts inspected without mutation; `blocked_on` means a gate that must become checked-present/accepted before the stage can claim its output. The machine-readable manifest records both fields separately and asserts the exact current manifest edges. The chain is:

`UP1-04A-VNEXT-T2 → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01 → UP2-02 → UP2-03 → UP2-04`.

The chain does not imply that T2 is ready: T2 itself is blocked on `UP1-04A-VNEXT-T1`, and T1 has the dual dependency `UP1-04A-VNEXT-T0` plus `UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC`.

## 5. Evidence classes and non-claims

Contract evidence covers typed fields, hashes, ownership and negative taxonomy. Compile evidence covers semantic AST/lowering and candidate-bound compiled residual receipts. Mesh evidence requires G2 chart metric, mesh, basis, quadrature and boundary ownership receipts. Provider evidence requires a current typed provider admission and execution receipt. Numerical evidence requires a closed candidate-bound discrete system, constraint residual and solver receipt. Physical evidence requires independently accepted physical validation. The current inventory supplies bounded contract/screen/fixed/manufactured/deferred artifacts only. No part of this repair claims UP2 acceptance, R credit, provider readiness, mesh readiness, coupled numerical convergence, engineering readiness or physical validity.

## 6. Cleanup

No cleanup was performed. Existing source, tests, runs, receipts and other agents' files remain untouched. The only new owned paths are `repair_r1/revised_report.md` and `repair_r1/manifest.json`; their exact-path inventory and self-hash treatment are recorded in the companion manifest.
