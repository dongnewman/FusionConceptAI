# Typed field and residual execution vertical slice

## 1. Purpose and present boundary

This slice turns declared G2 field programs into numerical arrays, binds them to G1 residual rows, and then assembles and solves only the operator subset for which the coordinate, boundary, source, unit, scenario, and numerical protocols are complete. Routing uses the full capability signature and typed references. Device family, display name, edge name, and region-name heuristics are outside the execution boundary.

The currently available repository and host can implement the producer and a bounded structured-grid solver. They do not provide qualified high-fidelity multiphysics software, an independent second code, engineering material/component data, or experimental validation data. Until those resources are supplied and admitted, integrated/VVUQ/engineering/validation obligations remain explicit gaps and the whole-device authority remains false.

The first implementation is a component of the declared S0-S8 chain. It must not be presented as a succession of unrelated demonstrations. Every result is consumable by the next typed object and carries the unresolved obligations that remain outside its scope.

## 2. Execution objects

### 2.1 G2 field producer

`FieldEvaluationPlanV4` is derived from one compiled candidate and binds:

- candidate and compiled-prefix hashes;
- G2 contract and Genome hashes;
- one exact `SpatialSupportGeneV1`, chart, `PhaseFieldSetGeneV1`, `TypedFieldProgramGeneV1`, and root;
- every `FieldProgramParameterBindingV1` and the derived `FieldParameterGeneV1` value, unit, and bounds;
- finite chart bounds, grid coordinates, scenario, allowed opcode set, numerical configuration, provider manifest, source-code hash, and plan hash.

The initial provider accepts one non-periodic three-dimensional chart and a finite rectilinear node grid. It evaluates the existing typed AST point by point and produces `FieldEvaluationResultV4(coordinates, values, output_type, extrema, result_hash)`. Algebraic operators are allowed only when their registered type/unit rules and the provider capability both allow them. Spatial derivatives, time derivatives, chart transitions, topology evolution, and unresolved references yield typed deferred gaps.

This result is a real evaluation of a declared field program. It is still `screen_only`; it does not establish a physical equation, PDE solution, field accuracy, or validation.

#### 2.1.1 Frozen producer authority

The first producer evaluates values in declared **chart-coordinate space**. A `CoordinateChartGeneV1` root reference is a declaration, not an implementation of its coordinate map or metric. Until a typed coordinate-map program and metric program are present and executed by qualified providers, the result must retain `g2_coordinate_map_unexecuted` and `g2_metric_unexecuted`. Those gaps do not prevent evaluation of an otherwise closed field program whose sole input is the declared chart coordinate, but the provider must not advertise ambient-coordinate, metric, gradient, divergence, Laplacian, PDE, or geometry-closure outputs. A site string such as `affine`, `cartesian`, or `euclidean` never proves one of those properties.

The callable factory interfaces are frozen as:

```text
compile_field_evaluation_plan(
  candidate::CandidateStatePackageV4,
  compiled::CompiledCandidatePrefixV4,
  genome_registry::GenomeContractRegistryV4,
  operator_registry::OperatorRegistryV1;
  scenario,
  grid,
  program_site_ref,
  root_position)

execute_field_evaluation(
  store::AbstractDict,
  candidate::CandidateStatePackageV4,
  compiled::CompiledCandidatePrefixV4,
  genome_registry::GenomeContractRegistryV4,
  operator_registry::OperatorRegistryV1,
  plan::FieldEvaluationPlanV4,
  scenario;
  provider)
```

Compilation first rederives and verifies the compiled prefix from the candidate, its frozen mission and bounds, and its comparison/scenario scopes. Execution repeats that verification and reconstructs the expected plan from the candidate, compiled object, registries, scenario, grid, program site, and root position. It compares the complete derived plan, rather than trusting a caller-supplied `status` or `plan_hash`. Plan and result types expose no public constructor that can independently assert ready, pass, or a result hash.

`FieldEvaluationPlanV4` binds the semantic Genome bundle hash and excludes candidate display ID, proposal lineage, archive metadata, and evidence history. It also binds the exact G2 hash, support and phase-set hashes, chart declaration and bounds, selected program/site/root position and hashes, exact bound parameter values/units/bounds, grid order, scenario hash, source-file hash, and the program's sorted `used_manifest_bindings`. Every used binding is re-resolved in the supplied `OperatorRegistryV1`; execution dispatches through a sealed kernel table keyed by the complete `(operator id, version, manifest hash)`. Dispatch by ID alone is forbidden.

The initial executable output is one static scalar root. The sealed operator subset is `IDENTITY@v1`, `ADD@v1`, `SUB@v1`, `NEG@v1`, `SCALAR_MUL@v1`, `SCALAR_DIV@v1`, and `DOT@v1`, each with the exact registered manifest hash. Vector/tensor output roots, derivatives, time-dependent roots, periodic execution, and unknown bindings remain typed gaps. The frozen callable has no `chart_ref` selector, so a multichart support is rejected before plan construction; the whole-candidate compiler and stage spine retain the corresponding unresolved capability. Additional unselected programs, roots, phase declarations, or parameters remain explicit scope gaps and are never silently counted as evaluated.

The provider manifest is a pure, idempotent function of the plan and uses one module-level executor whose code hash is derived from the real source bytes. It uses no mutable global plan registry. The immutable solver payload contains the complete execution plan data needed by that executor, and the executor recomputes its body hash before evaluation. Repeated manifest construction therefore returns the same manifest/executor binding and cannot be redirected by registering a forged object under an existing hash.

Successful evidence requires the exact local manifest, code hash, backend and revision, executor binding, input schema, physical subject, scenario, numerical configuration, and recomputed result artifact. Its status vector is `required / unique_match / resolved / low_fidelity_evaluated / pass`, its ceiling is exactly `screen_only`, and its artifacts contain the recomputed field result hash. Cache replay rechecks every one of those bindings. Field evidence preserves all compiler and whole-candidate gaps and closes no physical, VVUQ, engineering, validation, or P5 obligation.

### 2.2 Residual materialization declaration

The next boundary introduces a sealed `FieldResidualDeclarationV4`. It is runtime materialization data and does not pretend that missing G2 gene types already exist. It binds:

```text
candidate_hash / compiled_prefix_hash
g1_row_state_ref / g1_operator_site_ref / residual_root_ref
g2_support_ref / chart_ref
unknown_field_type_and_unit
coefficient_field_result_refs[]
source_field_result_refs[]
boundary_conditions[]
interface_conditions[]
initial_condition_or_null
mission_scenario_ref
discretization_protocol_ref
declaration_hash
```

Each coefficient or source reference must resolve to a candidate-bound field result or to an explicit mission/design-alternative value included in the physical-subject hash. A missing producer is a gap. The materializer never substitutes zero, a constant, or the first matching field.

`BoundaryConditionV4` binds an exact typed boundary node/site, state, component, condition kind, value program, units, and provenance. The first provider accepts Dirichlet data only. `InterfaceConditionV4` binds an exact typed interface site, its minus/plus endpoints, trace relation, full conservation ledger identity, and units. Interface execution remains deferred until both traces and the declared coupling operator are supported.

### 2.3 Residual assembly

`FieldResidualPlanV4` combines the materialization declaration with a frozen `DiscretizationProtocolV4`. The first executable domain is:

- static scalar fields on one exactly proven affine Cartesian chart;
- finite rectilinear grid with each axis count and total unknown count bounded;
- G1 residual roots composed from typed input/parameter/constant nodes and `IDENTITY`, `ADD`, `SUB`, `NEG`, `SCALAR_MUL`, `SCALAR_DIV`, `GRAD`, `DIV_OP`, and `LAPLACE` where registry types and units close exactly;
- Dirichlet boundaries covering the full external grid boundary;
- no event, moving topology, phase birth/death, chart transition, stochastic term, hidden source, or typed operator hole.

The affine Cartesian applicability proof is structural over the coordinate-map and metric typed programs. It must recognize an exact supported AST form and rational coefficients; a chart label such as `cartesian` is not proof. General curvilinear metrics remain deferred.

Assembly produces `ResidualAssemblyV4` with a deterministic sparse matrix or nonlinear residual callback, row-to-state/grid ownership, coefficient/source result hashes, boundary substitutions, unit checks, and an assembly hash. Every discrete row belongs to exactly one declared G1 residual row and grid location. Every input field value and boundary row has one exact producer. Duplicate, missing, or unconsumed rows fail closed.

For the linear initial subset, solve `A u = b` using a source-bound Julia implementation and report sparse-factorization and backward-error diagnostics. A later nonlinear subset may reuse the bounded Newton kernel only after its residual and Jacobian bindings are exact. `DT` is deferred until a mass-matrix, clock, initial-condition, time-grid, event, and DAE-index contract exists.

#### 2.3.1 Frozen first residual-solve interface

The first executable residual provider supports one static scalar unknown on one three-dimensional rectilinear grid under an explicitly declared diagonal affine map. This is a complete numerical path for that declared subject, not evidence for an omitted geometry or a different equation.

`DiagonalAffineChartGeometryV4` is derived by `compile_diagonal_affine_geometry` from the candidate, compiled prefix, exact support/chart references, three nonzero rational dimensionless diagonal factors, three rational normalized offsets, the grid, and the support's strictly positive `resolution_independent_scale`. It verifies the chart input/output and normalized-metric declaration types and checks every chart-coordinate grid node against the declared chart bounds. For normalized coordinates it derives `J_hat = diag(a1,a2,a3)` and `g_hat = transpose(J_hat) * J_hat`; the physical Jacobian is `J = L * J_hat`, where `L` is the declared SI length scale. The discrete physical Laplacian therefore uses `1 / (L^2 * ai^2)` on axis `i`. `geometry_hash`, capability bounds, assembly, and physical subject bind the scale's value and unit as well as `J_hat`, `g_hat`, and the grid. Doubling `L` with the same normalized field and grid must divide the Laplacian contribution by four. No caller-supplied metric or geometry label can override these relations. The runtime completion still retains `g2_coordinate_map_program_unavailable` and `g2_metric_program_unavailable`: the current G2 chart carries typed root declarations rather than executable map/metric programs, and this completion must not be reported as Genome-program execution or geometry closure.

The residual declaration is constructed only through:

```text
compile_field_residual_plan(
  candidate::CandidateStatePackageV4,
  compiled::CompiledCandidatePrefixV4,
  genome_registry::GenomeContractRegistryV4,
  operator_registry::OperatorRegistryV1,
  geometry::DiagonalAffineChartGeometryV4,
  source_reports::Tuple{Vararg{FieldEvaluationReportV4}},
  boundary_report::FieldEvaluationReportV4;
  scenario,
  grid::FieldGridSpecV4,
  constraint_edge_hash::Digest256,
  unknown_state_ref::StateGeneRefV1,
  source_state_refs::Tuple{Vararg{StateGeneRefV1}},
  residual_state_ref::StateGeneRefV1,
  protocol::StructuredGridProtocolV4)
```

`constraint_edge_hash` must select exactly one `AtomicMIMOHyperedgeV1` with role `constraint`; the edge display ID is never a routing input. Its exact input/output bindings must map the declared unknown, sources, and residual state to typed graph state nodes. Every source ref has exactly one evaluated field report in the same candidate, prefix, grid, and scenario. The boundary report has the unknown type and covers the same ordered coordinates. Each report is rederived from its plan, its values and result hash are recomputed, and its provider, physical subject, solver input, evidence, artifact, code hash, and `screen_only` ceiling are checked. A self-consistent result hash without this chain is insufficient.

The executable AST subset is a linear expression over the exact unknown and declared source inputs using `IDENTITY@v1`, `ADD@v1`, `SUB@v1`, `NEG@v1`, `SCALAR_MUL@v1`, `SCALAR_DIV@v1`, and `LAPLACE@v1`, each keyed by its literal audited manifest hash. Multiplication or division requires one finite scalar constant and cannot divide by zero. `LAPLACE` may apply only to the selected unknown. Compilation symbolically derives one affine stencil expression and rejects nonlinear products, a source under `LAPLACE`, multiple unknowns, unused or unconsumed inputs, unit mismatch, and any operator outside this set. `GRAD`, `DIV_OP`, `CURL`, and `DT` remain deferred.

`StructuredGridProtocolV4` initially fixes `second_order_centered`, `dirichlet_elimination`, and Julia `SparseArrays`/`LinearAlgebra` sparse solve. Every axis has 3 to 33 uniformly spaced nodes and the total unknown count is at most 35,937. Dirichlet values cover all six external faces; duplicate corner/edge values must agree exactly after normalization. Missing faces and implicit zero/default values are rejected.

The executable calls are:

```text
assemble_field_residual(plan::FieldResidualPlanV4)::ResidualAssemblyV4

execute_field_residual(
  store::AbstractDict,
  candidate::CandidateStatePackageV4,
  compiled::CompiledCandidatePrefixV4,
  genome_registry::GenomeContractRegistryV4,
  operator_registry::OperatorRegistryV1,
  plan::FieldResidualPlanV4,
  scenario;
  provider)::FieldResidualReportV4
```

`ResidualAssemblyV4` seals the sparse matrix, right-hand side, row ownership `(residual_state_ref, grid_index)`, source/boundary artifact hashes, geometry, units, substitutions, and assembly hash. `FieldSolveResultV4` is token-constructed only after solving and recomputes the assembled residual norm, boundary mismatch, finite-value checks, sparse-factorization and backward-error diagnostics, termination reason, and result hash. The provider code hash is the SHA-256 of its actual source file and its executor is a stable module function. Deferred plans have no provider manifest, subject, solver input, callback, result, or evidence.

A successful execution emits ordinary `RuntimeEvidenceV4` at exactly `screen_only`. It resolves only a work item whose key contains candidate Genome hash, compiled-prefix hash, stage, scenario, `constraint_edge_hash`, unknown/source/residual refs, grid, geometry, protocol, and capability signature. It never removes a generic `required_physical_capability` gap and never calls global candidate release. A singular or ill-conditioned system, nonfinite evaluation, or tolerance failure records a replayable failed attempt and is not a permanent-prune certificate.

### 2.4 Result and evidence

`FieldSolveResultV4` contains the solution field, true assembled residual norm, boundary mismatch, interface mismatch or null, ledger balance residuals, solver history, conditioning diagnostics, termination reason, and result hash. A converged status cannot be supplied by a public constructor independently of these recomputed quantities.

`FieldSolveEvidenceV4` binds the candidate, physical subject, G1 residual rows, G2 producer artifacts, scenario, grid, materialization declaration, assembly, provider/code/backend, numerical configuration, result, and unresolved obligations. During the first slice its claim ceiling is `screen_only`. Promotion to candidate-bound numerical evidence requires a separate authority change plus convergence evidence; it is not obtained by renaming the current status.

## 3. Capability routing

The field producer uses an exact `g2_typed_field_evaluation` capability. The residual provider uses an exact `structured_field_residual_solve` capability whose signature includes:

```text
operator_set and residual form
state tensor rank and units
source and target spaces
spatial dimension and coordinate proof class
boundary and interface relation
time semantics
required outputs
applicability bounds
input schema hash
evidence level
```

Provider matching must also verify the local source hash and executor binding. A provider that matches the abstract signature but has a different implementation, backend revision, independence group, schema, or executable is out of the local execution domain. It cannot borrow another provider's evidence identity.

Compiler integration removes only the exact gap proven by the declaration and provider. For example, a complete affine chart may resolve `required_coordinate_declaration` for one residual plan while equilibrium, orbit, stability, transport, engineering, control, and whole-device obligations remain. The compiler must never replace every `required_physical_capability:*` gap with one generic field-solver pass.

## 4. Stage and archive connection

The end-to-end flow is:

```text
CandidateStatePackageV4
  -> compiled prefix with all gaps
  -> G2 FieldEvaluationPlanV4 and field artifacts
  -> FieldResidualDeclarationV4
  -> ResidualAssemblyV4
  -> FieldSolveResultV4 and scoped evidence
  -> exact stage-evidence binding
  -> stage frontier or local deferred archive
  -> recompile/re-evaluate only after a declared producer/provider change
  -> whole-device closure audit with remaining gaps
```

Field evaluation can supply part of S2 field/source realization. A residual solve can close only the registered low-fidelity obligation for the solved rows and scenarios. It does not automatically close S3 orbit/end-loss, S4 equilibrium, S5 stability, S6 transport/reaction/power, S7 engineering/control, or S8 integrated high-fidelity/VVUQ. A numerical failure is a replayable attempt and may enter an infeasible frontier; it is not a permanent prune certificate. Provider absence remains deferred, and resolving local work never calls global candidate release directly.

All mission operating and fault scenarios in the frozen scope are universally quantified. Results for one scenario cannot close another. Frontier admission requires exact coverage of the stage manifest; post-execution closure requires the corresponding result evidence.

## 5. Numerical VVUQ extension

After the single-grid residual path is correct, add `DiscretizationStudyV4` over at least three predeclared grids. It records restriction/prolongation, solution and functional differences, observed order, residual tolerance, roundoff sensitivity, asymptotic-range checks, and study hash. Manufactured solutions are useful regression controls and must be labeled `manufactured_control`; they do not validate a real device or model.

Parameter UQ requires declared distributions or bounded sets, units, correlation assumptions, sampler rule, seed, coverage, and convergence diagnostics. Unknown uncertainty is serialized as null and blocks the corresponding UQ closure. Multiple linear solvers or two wrappers around the same assembler are numerical cross-checks, not independent-code evidence.

S8 integrated numerical execution and VVUQ remains deferred until a qualified integrated solver and its numerical-convergence evidence satisfy that stage's contract. Independent-code comparison, engineering closure, and validation remain separate later-stage obligations; each stays deferred until its own evidence contract is satisfied and none is used as a substitute for another.

## 6. Acceptance matrix

| Boundary | Positive acceptance | Required negative control |
|---|---|---|
| G2 extraction | unique exact support/chart/set/program/root/parameter bindings | duplicate, dangling, wrong type/unit/bounds, name-only match |
| field evaluation | nontrivial analytic typed field agrees at several grid points and has a stable artifact hash | unsupported derivative, foreign provider, forged prefix/plan, nonfinite value, cache mismatch |
| materialization | every residual input, boundary row, source, and scenario has one typed producer | implicit zero/default, missing boundary, unconsumed coefficient, ambiguous interface |
| assembly | deterministic rows, exact row ownership, units, boundary coverage, source hashes | wrong endpoint, unit mismatch, duplicate/missing row, unsupported chart/operator |
| solve | recomputed residual and boundary norms meet frozen tolerances | singular, ill-conditioned outside bounds, nonconverged, false status, out-of-bounds grid |
| grid VVUQ | at least three grids and replayable convergence diagnostics | one-grid accuracy claim, manufactured control presented as validation |
| orchestration | only exact scoped obligation resolves; all unrelated gaps remain | generic physical-gap removal, global release, S3-S8 promotion from this result |

Tests must exercise a nonzero source and nonconstant solution, verify multiple grid values and true residuals, perturb coefficients/boundaries to change the subject/result hashes, and show that tuple ordering and scheduling do not change canonical results.

## 7. Resources required for higher stages

The implementation can autonomously research and integrate public data and open solvers when their licenses, provenance, versions, input schemas, and build hashes can be recorded. The remaining inputs split into public resources we can seek and project-specific resources that cannot be inferred.

Public-resource work includes locating qualified benchmark cases, open solver implementations, published material properties with uncertainty, and openly licensed validation datasets, followed by source and reproducibility review.

New-device geometry, meshes, material/component combinations, and actuator/control alternatives should normally be generated from the three Genomes or selected from qualified public catalogs; they are search outputs, not assumed user-supplied designs. Their generated provenance, bounds, and consumers must still close exactly.

Project-specific inputs that require the user or another authoritative project source are:

- mission operating and fault scenarios with finite bounds;
- user-specific geometric envelopes, exclusions, boundary/interface constraints, or private CAD that are not declared by the mission;
- private catalog properties or user-specific material, source, actuator, sensor, controller, protection, load, thermal, stress, and manufacturability limits with units and uncertainty;
- private or licensed solver/data credentials and proprietary material/component information;
- private benchmark or experimental observations, their calibration/validation split, covariance/error model, and acceptance protocol;
- access to non-public compute resources when the declared discretization and scenario ensemble exceeds the local host.

Open solver executables and public datasets do not require another permission request within this task. Their evidence still must pass the same provenance and qualification gates.

Without these resources, the software chain can execute and report exact gaps, but cannot truthfully produce high-fidelity whole-device, engineering, independent-code, or validation evidence.
