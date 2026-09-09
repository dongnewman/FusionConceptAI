# Gridap and numerical V&V reuse-first audit

## Decision and boundary

This audit is the mandatory reuse-first gate before the candidate-bound Gridap
field adapter and the later two-discretization numerical V&V milestone.  It
applies the repository migration rules to the legacy implementation under
`outputs/fusion_concept_ai/` and to the already frozen Runtime V4 field slice.

The audit found no legacy Gridap, finite-element mesh, or weak-form assembly
that can be extracted into Runtime V4.  Batch B therefore requires a new,
independent Gridap assembly.  Reuse is limited to typed Runtime V4 inputs and
to fail-closed V&V algorithms or test intent.  No legacy run, reduced proxy,
two-dimensional smoke result, or native finite-difference result is admissible
as independent FE evidence, physical validation, engineering closure, or P5
evidence.

This conclusion does not change the current evidence ceiling:
`manufactured_control`, `screen_only`, zero credible physical candidates, and
`p5_ready=false`.

## Sources inspected

Legacy numerical and V&V sources:

- `outputs/fusion_concept_ai/src/numerical_verification.jl`;
- `outputs/fusion_concept_ai/src/solvers/generic_ode_dae_event_adapter.jl`;
- `outputs/fusion_concept_ai/src/candidate_vvuq_runtime_v87.jl`;
- `outputs/fusion_concept_ai/src/generic_vvuq_runtime_v94.jl`;
- `outputs/fusion_concept_ai/src/physical_vvuq_runtime_v96.jl`;
- their focused tests and compile/run scripts;
- the legacy `src/adapters/` tree and legacy `Project.toml`.

Current Runtime V4 and qualification sources:

- `src/RuntimeV4/FieldResidualNumerics.jl` and its focused tests;
- `src/RuntimeV4/FieldResidualPipeline.jl` and its focused tests;
- `tools/qualification/gridap/{Project.toml,Manifest.toml,README.md,smoke.jl}`;
- `docs/implementation/gridap_field_adapter_plan.md`;
- `docs/implementation/fd_to_integrated_vvuq_path.md`.

The legacy project has no Gridap dependency or FE implementation.  Its
numerical verification is analytic/time-refinement or dense-matrix/reduced
graph work.  The current Gridap smoke is a non-candidate-bound 2D environment
check, not an adapter qualification.

## Extract, wrap, test-only, reject

| Decision | Source | Permitted use | Prohibited use |
|---|---|---|---|
| extract | legacy analytic/refinement and V&V runtimes | minimum refinement levels, unique input/result hashes, deterministic replay, negative controls, separate numerical/model/measurement/transfer records | copying legacy `Dict` schemas, status strings, candidate identity, or authority |
| wrap | v87/v94/v96 record and gate logic | new typed, candidate-bound report validation after rederiving subject, scenario, protocol, provider, input, result, and evidence identities | wrapping an old result as new Runtime V4 evidence or inheriting an old claim ceiling |
| extract | `FieldResidualNumerics.jl` and `FieldResidualPipeline.jl` | frozen typed form, signed geometry, G2 source/boundary reports, scenario, subject, solver-input, and canonical identity conventions | calling or inspecting the native assembler, matrix, receipt, or solution inside the Gridap provider |
| test-only | legacy numerical tests and Gridap smoke | sentinel design, malformed/missing input cases, convergence and replay test intent, dependency-load preflight | evidence of a candidate-bound 3D solve, independent assembly, or numerical V&V |
| reject | legacy adapters, reduced proxies, and historical artifacts | counterexample and interface-design reference only | FE provider implementation, independent-code credit, physical/experimental validation, engineering closure, or promotion |
| reject | family/name/ID/position routing and legacy authority | adversarial regression cases only | provider selection, candidate preference, terminal classification, or pruning |

## Input and output mapping for Batch B

The new adapter may consume only rederived Runtime V4 inputs:

- candidate, compiled prefix, Genome and operator registries;
- the frozen field residual plan, exact G1 edge and linear typed form;
- signed diagonal-affine geometry and structured G2 grids;
- executed G2 source and Dirichlet reports with plan/result/provider/payload
  hashes;
- frozen mission and named scenario;
- explicit Gridap protocol and pinned dependency identity.

The adapter emits new sealed Gridap artifacts only:

- an executable/deferred Gridap plan;
- a weak-form assembly receipt without serialized Gridap runtime objects;
- a solve result with recomputed algebraic residual, boundary mismatch, L2 and
  H1 errors, and interpolation errors kept separate;
- a source-bound provider, solver input, `RuntimeEvidenceV4`, and report whose
  ceiling is exactly `screen_only`.

It must not emit validation, UQ, engineering, integrated-device, promotion,
archive, pruning, or final-authority records.

## Batch B implementation decision

Build a new optional adapter in the isolated pinned Gridap environment.  It
uses a real 3D Cartesian hexahedral Q1/H1 weak form and tensor-product
trilinear interpolation of the executed G2 node values.  It must assemble its
own matrix and vector through Gridap, solve them, and recompute the free-DOF
residual from the Gridap operator.

The adapter must not call `assemble_field_residual`,
`assemble_field_residual_kernel`, `_fr_matrix`, or consume a native CSC or
native assembly/result receipt.  A native-assembler sentinel is a required
negative control.  The Gridap provider cannot silently fall back to the native
provider when Gridap or its exact dependency lock is missing or mismatched.

Batch B is split into independently reviewable commits:

1. **B1 numerical kernel** -- one real 3D Gridap solve, G2 interpolation,
   signed coordinate mapping, recomputed residual, wrong-sign control, and
   native-assembler sentinel;
2. **B2 convergence** -- real 5/9/17-node solves with separate solution L2,
   H1 seminorm, source interpolation, and boundary interpolation errors, then
   freeze observed Q1 acceptance intervals;
3. **B3 bindings** -- sealed plan/receipt/result/provider/input/evidence,
   dependency and source identities, replay, foreign-binding and false-status
   controls, while preserving all Batch A file hashes.

The later Batch C may wrap the legacy refinement/gate ideas only after both
native and Gridap reports independently replay.  It must use an explicit
transfer operator and keep native Linf, Gridap L2/H1, transfer, solver, and
discretization errors distinct.

## Acceptance gate

Before each Batch B or C commit:

1. record exact legacy and current sources and classify each as extract, wrap,
   test-only, or reject;
2. rederive every input from public Runtime V4 constructors and reject foreign
   candidate, prefix, scenario, edge, root, grid, protocol, provider, and lock;
3. prove the Gridap matrix/vector came from the independent weak form and that
   the native assembler sentinel remained untouched;
4. retain `numerical_fail`, `unknown`, `deferred`, `unsupported`, and
   not-applicable as distinct states;
5. run dependency, finite-value, residual, boundary, interpolation,
   convergence, determinism, replay, and manufactured-as-validation negative
   controls;
6. run focused tests, the Gridap runner, relevant Runtime V4 regressions, and a
   final architecture audit;
7. commit and push only that milestone, without changing frozen Batch A files.

Any failed gate leaves a replayable gap or failed numerical report.  It cannot
be converted into a physical failure, permanent pruning decision, or broader
authority claim.
