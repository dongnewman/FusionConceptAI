# Candidate-bound 3D Gridap field adapter plan

## Scope and evidence boundary

Batch B adds a real three-dimensional finite-element solve for the existing
static scalar residual subject. It consumes the frozen `FieldResidualPlanV4`,
its candidate-bound G2 source and boundary reports, its
`LinearFieldResidualFormV4`, and its `DiagonalAffineChartGeometryV4`.

The adapter is a second assembly implementation. It must assemble a Gridap
weak form and must never call `assemble_field_residual`,
`assemble_field_residual_kernel`, `_fr_matrix`, or consume the native finite
difference CSC payload. Sharing the typed candidate, compiled form, G2 reports,
geometry, and scenario is intentional; sharing the native assembler is
forbidden.

The result ceiling remains exactly `screen_only`. The quartic case is a
manufactured software control. A pass provides no physical-model validation,
experimental validation, engineering closure, integrated high-fidelity
result, S8--S10 closure, P5 readiness, or credible physical candidate.

Implement in this order:

1. one real 3D Gridap Q1 solve with a recomputed algebraic residual;
2. real 5/9/17-node solves with separate L2 and H1 convergence;
3. candidate, dependency, provider, receipt, and evidence bindings;
4. mandatory adversarial controls.

Do not add another archive, promotion, authority, or whole-device layer in
this batch.

## Additive files and environment

Keep every frozen Batch A file byte-identical. Add only:

```text
src/RuntimeV4/GridapFieldResidualAdapter.jl
examples/runtime_v4_gridap_field_fixture.jl
scripts/run_v4_gridap_field_residual.jl
test/runtime_v4_gridap_field_residual_tests.jl
docs/implementation/gridap_field_adapter_plan.md
```

Use the existing read-only `tools/qualification/gridap` environment. Do not
add Gridap to the main package Project/Manifest and do not modify the
qualification files. The Gridap runner adds the repository project to
`LOAD_PATH`, loads `FusionConceptAI`, includes the frozen
`RuntimeV4/FusionRuntimeV4.jl`, and uses `Base.include` to load the new adapter
into that module. The default package load therefore remains independent of
Gridap during the first numerical milestone.

The published smoke proves only that the pinned Gridap environment can load
and execute its small two-dimensional Poisson example on this host. It is not
candidate-bound adapter qualification, numerical-convergence evidence, an
independent-code result, or Runtime V4 evidence. Batch B must produce all
three-dimensional solve, convergence, and binding evidence described below.

The provider must bind and verify:

| Item | Identity |
|---|---|
| Julia | `1.10.5` |
| published platform | `x86_64-w64-mingw32` |
| Gridap UUID | `56d4f2e9-7ea1-5844-9cf6-b9c51ca7ce8e` |
| Gridap version | `0.20.8` |
| Gridap source tree | `95fd6ec47697c8f031398434a119abe747330715` |
| qualification Project SHA-256 | `223FB6C8EA33F03989CCB4D76ED80016A3BC2799BC4210490C4E43CC7AFFCEB6` |
| qualification Manifest SHA-256 | `2E1D103396D3F3FAA13687BD4A95FDE287D1F94E8B0006046B65E1E29AA3765A` |

Bind raw lock-file hashes and parsed package identity. A byte, UUID, version,
or tree mismatch is a typed dependency gap; it cannot silently fall back
under the Gridap provider identity.

## Adapter contracts

All ready, receipt, result, and report types use private construction tokens.

```julia
GridapFieldProtocolV4(
    cell_family = :cartesian_hexahedral,
    fe_family = :lagrangian_q1,
    conformity = :H1,
    boundary = :dirichlet_strong,
    quadrature_degree = 8,
    solver = :gridap_sparse_lu;
    residual_abs_tol = 1e-10,
    residual_rel_tol = 1e-10,
)
```

The first provider accepts these literal choices only. The protocol also
binds `:tensor_product_trilinear_from_g2_nodes`, the manufactured exact-value
and gradient evaluator revision, and the dependency identity.

```julia
compile_gridap_field_residual_plan(
    candidate::CandidateStatePackageV4,
    compiled::CompiledCandidatePrefixV4,
    genome_registry::GenomeContractRegistryV4,
    operator_registry::OperatorRegistryV1,
    native_plan::FieldResidualPlanV4,
    scenario::NamedTuple;
    protocol::GridapFieldProtocolV4 = GridapFieldProtocolV4(),
)::GridapFieldResidualCompilationV4
```

Compilation rederives `native_plan` through the public residual-plan compiler.
It verifies candidate, prefix, edge, form, geometry, ordered state refs, every
G2 plan/result/provider binding, scenario, and audited operator-manifest
triple. It may reuse typed compilation and materialization. It may not invoke
or inspect the native numerical assembly.

`GridapFieldResidualPlanV4` binds candidate and Genome hashes, prefix, mission,
bounds, edge, form, state refs and types, signed geometry, grid, source and
boundary reports, scenario, protocol, dependency lock, adapter source, status,
gaps, and plan hash. A deferred input produces no provider or executable.

`GridapAssemblyReceiptV4` records physical domain, cells, FE/test/trial-space
identity, quadrature degree, free/Dirichlet DOF counts, all typed input hashes,
dependency and source identities, weak-form revision, and assembly hash. It
does not serialize Gridap runtime objects.

`GridapFieldSolveResultV4` records status, ordered free DOFs, deterministic
physical sample values, `norm(A*x-b, Inf)` recomputed from Gridap
`get_matrix(op)` and `get_vector(op)`, boundary mismatch, L2 error, H1
seminorm error, source and boundary interpolation errors, finite-value and
termination diagnostics, receipt/protocol hashes, and result hash.

`GridapFieldResidualReportV4` binds plan, receipt, result,
`ExecutablePhysicalSubjectV4`, `SolverInputV4`, `RuntimeEvidenceV4`, gaps, and
the `screen_only` ceiling. Numerical failure remains a replayable failed
report and cannot enter a passing convergence study or resolution.

## Physical mapping and G2 interpolation

For chart coordinate `q`, use the declared map

```text
x_i = L * (a_i * q_i + o_i)
q_i = (x_i / L - o_i) / a_i
```

with positive `L` and the original signed nonzero `a_i`. The Cartesian model
uses sorted physical endpoints. A G2 grid with `(n1,n2,n3)` nodes maps to
`(n1-1,n2-1,n3-1)` hexahedral cells.

The source and Dirichlet functions are deterministic tensor-product
trilinear interpolants of the real G2 report values. This is an FE input
approximation, not the exact continuous field and not the native discrete
equation. Protocol, receipt, and result must separately record:

```text
input_field_representation = tensor_product_trilinear_from_g2_nodes
source_interpolation_error = measured
boundary_interpolation_error = measured
```

For the manufactured control, measure source interpolation L2 discrepancy and
boundary interpolation discrepancy against the typed-AST exact evaluator.
Keep both separate from solution L2/H1 error and from later native-to-Gridap
transfer error.

## Weak form and exact manufactured metrics

The frozen form represents

```text
alpha * Laplace(u) + beta * u + sum(gamma_i * source_i) + constant = 0.
```

Assemble only

```text
a(u,v) = integral(alpha * grad(v) dot grad(u) - beta * v * u) dOmega
b(v)   = integral(v * (sum(gamma_i * source_i) + constant)) dOmega
```

and solve `a(u,v)=b(v)`. This sign follows integration by parts after
multiplying the declared residual equation by minus one.

Accept only the audited static scalar 3D linear subset: `IDENTITY`, `ADD`,
`SUB`, `NEG`, `SCALAR_MUL`, `SCALAR_DIV`, and `LAPLACE`, all at `v1` with
literal manifest hashes. `LAPLACE` acts only on the selected unknown.
`ASTParameterV1` inside the G1 residual program, nonlinear products, source
derivatives, `GRAD`, `DIV_OP`, `CURL`, `DT`, interfaces, motion, stochastic
terms, and hidden defaults are deferred. This G1 restriction does not defer
G2 field parameters. The existing G2 producer continues to rederive and bind
`FieldParameterGeneV1` values and their units and bounds; the quartic
fixture's `source_scale` therefore remains a supported, executed G2 input.

The manufactured exact value and gradient use a separate sealed typed-AST
value/gradient evaluator over the same manifest triples. It derives the
quartic derivative from the AST, never from a root name or hard-coded `x^4`
function. Convert chart gradient with

```text
grad_x = diag(1 / (L * a_i)) * grad_q.
```

This exact evaluator is for error metrics only. FE assembly continues to use
the interpolated real G2 reports.

## Provider identity

```text
kind               = gridap_weak_form_field_residual_solve
backend            = gridap-linear-fe-lu
independence_group = gridap-weak-form-assembly-v1
claim_ceiling      = screen_only
```

Code hash covers adapter source bytes. Backend revision/domain bind Julia,
platform, Gridap UUID/version/tree, both qualification hashes, weak-form and
interpolation revisions, FE family, and solver. Input schema binds candidate,
prefix, form, geometry, all G2 artifacts, scenario, protocol, and requested
capability. The executor is one stable module function and returns only the
sealed result artifact hash.

The independence group records a separate assembly implementation. It is not
itself a numerical-V&V or validation receipt. Native-to-Gridap comparison,
field transfer, norm reconciliation, and transfer error belong to Batch C.

## Acceptance matrix

Primary runs use 5, 9, and 17 nodes per axis, or 4, 8, and 16 cells per axis.

| Boundary | Positive control | Mandatory negative control |
|---|---|---|
| dependency | exact lock, Gridap 0.20.8 and source tree | changed lock byte, UUID/version/tree mismatch, missing Gridap |
| candidate | public rederivation of candidate, prefix, edge, form, geometry, G2 reports and scenario | foreign candidate/prefix/scenario/edge/root/grid, missing or forged G2 payload |
| independent assembly | real 3D Gridap matrix/vector, nonzero cells and DOFs | native-assembler sentinel remains uncalled; native CSC/receipt rejected |
| weak form | nonzero source, nonconstant solution, signed affine map and several sample values | wrong sign/source order/unit/scale/factor/boundary root, unsupported AST |
| solve | finite DOFs, recomputed residual and boundary mismatch within protocol | singular/nonfinite solve, false status, foreign executor/provider |
| interpolation | source/boundary interpolation rule and measured errors are explicit | omitted interpolation budget or exact-continuous-input claim |
| convergence | three real 3D solves; finite solution L2 and H1 errors; Q1 trends | one/nonrefining grid, mixed subject/protocol, numerical failure, manufactured-as-validation |
| authority | evidence remains `screen_only`; physical/engineering/integrated/validation/P5 stay open | higher ceiling, global release, physical or validation claim |

Expected Q1 behavior is solution L2 order near two and H1 seminorm order near
one. Freeze exact acceptance intervals only after the first clean 5/9/17 run,
because G2 source and boundary interpolation contribute to the measured
errors and may not be omitted.

## Milestones and stop rules

### B1: real numerical kernel

Build one 3D Gridap model, interpolate real G2 source and boundary reports,
assemble the weak form, solve with LU, and recompute the free residual. Include
wrong-sign and native-assembler-sentinel controls. If this fails, diagnose the
weak form, mapping, or Gridap API; never substitute the native result.

### B2: convergence

Run 5/9/17 and record cells, DOFs, residual, boundary mismatch, solution L2,
solution H1 seminorm, source interpolation L2, boundary interpolation error,
runtime, and memory for each level. Freeze observed acceptance intervals. If
the norms do not converge, preserve numerical-failure reports and diagnose
before adding more evidence machinery.

### B3: binding and adversarial controls

Seal plan, receipt, result, provider, solver input, evidence, and replay.
Complete dependency, foreign binding, unsupported AST, missing payload,
mixed-grid, and false-status controls. Verify every frozen Batch A file hash.

Batch B ends only after B1--B3 pass with zero credible physical candidates and
`p5_ready=false`. Batch C then compares native Linf and Gridap L2/H1 results
through an explicit transfer operator and keeps transfer error separate.
