# UP2-01 physical compiler entry audit R2

Verdict: `ready_for_future_dispatch` with dispatch held by the formal dependency gate.

This is a read-only architecture and evidence audit at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The worktree already contained 294
dirty/untracked status rows. No Julia or DESC process was present at either
process sweep, and this audit did not start Julia or DESC. Only this new
`entry_audit_r2/` directory is written. The claim ceiling is
`preparation_static_audit_no_Julia_DESC_no_core_change_no_physical_credit`.

## Dependency status

The task manifest keeps `UP2-01` `planned` and dependent on `UP1-04`. `UP1-04A`
is only `accepted_limited` for additive V5 shared entry and structural
same-candidate identity wiring. `UP2-00` remains `review_pending`/`accepted=false`
with only the actual-A N01/N02 projection slice independently reviewed; 40 of
50 formal rows remain pending. `UP1-04B` is `planned`: the six B00 cases, 50
fresh candidate-bound B04 mutation receipts, checker, and two-process replay are
not present. Therefore UP1-04 is not closed and UP2-01 is not dispatchable for
execution. The formal release condition is: independent acceptance of UP2-00,
then UP1-04B's complete B00/B04 receipt/checker/two-process replay and independent
review, then UP1-04 package join acceptance. No local `accepted_limited` slice
may substitute for that chain.

## What is present

The V5 layers provide typed declarations and candidate identity. G1 has
`G1EquationV2`, `G1EquationPlanV2`, typed expression DAGs, state/parameter
inputs, units, ranks, temporal kind, derivative order, effects, closure and
ledger occurrences (`src/GenomeV5/G1/EquationPlanV2.jl:1-239`). G2 has typed
regions/interfaces, chart and embedding, scalar/vector field space, mesh/basis/
quadrature and exterior boundary plans (`src/GenomeV5/G2/RegionInterfaceContractV2.jl:22-111`,
`src/GenomeV5/G2/FieldSpacePlanV2.jl:3-198`). G3 has typed resource/ledger,
material and control declarations plus feedback channels; its feedback checker
deliberately retains `feedback_authority_gap` until exact integrated refs and
external authority exist (`src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:22-90`).

`CandidateStatePackageV5` is additive and candidate-bound, but its constructor
requires `resolution=terminal_deferred` and `claim_ceiling=none` for the current
UP1-04A scope (`src/Contracts/CandidateStatePackageV5.jl:159-230`). E0 binds
the package and component identities. G-I1A rebuilds and validates that context,
keeps E1/E2 absent/deferred when authority is missing, fixes
`physical_resolution=terminal_deferred`, and enforces zero compile/provider/
solver counters (`src/GenomeV5/UP2/GI1AuthorityContextV1.jl:266-367,440-528`).
These are useful source-backed identity inputs and explicit authority gaps; they
are not equation, mesh, provider, solver, or physical evidence.

## Current executable entry points and exact gaps

| Chain edge | Current entry | Static result | Missing API or proof |
|---|---|---|---|
| candidate → equation IR | `compile_candidate(candidate::CandidateStatePackageV4, ...)` | V4-only structural prefix; emits `CompiledCandidatePrefixV4` obligations | `compile_candidate(::CandidateStatePackageV5, ...)` and typed `EquationIRV4` are absent; no V5 G1 equation lowering (`src/RuntimeV4/Compiler.jl:102-154`). |
| equation IR → solver input | `compile_field_residual_plan(::CandidateStatePackageV4, ...)` | exact manufactured six-node `LAPLACE(u)-2f`; evidence class `manufactured_control` | `WeakResidualIRV4`, `DiscreteResidualV4`, `SolverPlanV4` and V5 package-bound lowering are absent. `GRAD`, `DIV_OP`, `LAPLACE`, and `DT` remain deferred in field evaluation (`src/RuntimeV4/FieldProgramEvaluation.jl:10-14,298-390`). |
| solver input → spatial residual | `field_residual_provider` and standalone `solve_multiregion_diffusion` | fixed structured V4 screen; the latter is two 1-D regions with one constant `Float64 conductivity` per region and uniform mesh requirement | no V5 candidate-owned coefficient field, chart/metric/function-space execution, general mesh/assembly, or conservative variable-coefficient flux provider (`src/RuntimeV4/FieldResidualPipeline.jl:334-408,522-536`; `src/RuntimeV4/MultiRegionDiffusionProvider.jl:229-290`). |
| spatial residual → G3 feedback | typed `G3FeedbackChannelV2` and G-I1A context | structural channel/identity only; authority and physical resolution deferred | no same-candidate residual receipt joined to feedback `source_id`, target ref/hash, subject/solver hashes, units, status and failure taxonomy. |

`SpatialRuntimeV4.jl` is a once-only fixed source loader (`:unloaded → :loading
→ :loaded`), not a V5 candidate-input compiler (`src/RuntimeV4/SpatialRuntimeV4.jl:3-37`).
`SpatialMultiRegionV4.jl` remains a fixed two-region static-MHD/Q1 slice with
fixed declaration, states and interface; its W24 artifacts record solver exit 4
iteration-limit and physical validation unsupported/deferred. The prior current
spatial audit is retained and not reclassified.

The exact six-node manufactured screen has value as a regression control. It
must remain labeled `manufactured_control`/`screen_only`; its second-order
convergence receipt does not demonstrate declaration-driven compilation,
variable coefficients, a candidate-owned physical provider, or G3 feedback.

## Minimal future work order: one variable-coefficient diffusion slice

The smallest legal UP2-01 slice is one actual V5 package with one scalar G1
state `u`, one positive scalar coefficient field `K(x)` (or explicitly typed
SPD tensor only if the same work order supplies its tensor/unit rules), one
source `f`, one G2 region/chart/metric/function-space, and one explicit
Dirichlet or Neumann ownership. Use the declaration
`-div(K grad(u)) = f` on a bounded Cartesian 3-D chart, with a serial structured
mesh as the first backend. A constant coefficient is a legal special case for
the positive control, but the implementation must accept at least two
candidate-owned coefficient profiles without source edits; `K` cannot be a
hidden closure or family branch.

The input must be reconstructed from the package and typed declarations:

* G1 state/equation/typed expression, operator and closure refs, source and
  residual units, ledger occurrence/account refs, and candidate/component hashes;
* G2 region/chart/embedding/metric/function-space, mesh/basis/quadrature,
  boundary faces and ownership, with a candidate-bound geometry/plan hash;
* G3 source/return/heat/ledger ownership and a feedback target declaration. The
  existing N05/N06 and G-I1A authority gaps remain `terminal_deferred`; they
  cannot be filled by a prose mapping, fixture label or synthetic ref;
* a provider capability signature covering operator set, state/source/target
  spaces, dimension/chart, boundary/interface relation, time semantics, output,
  input schema and applicability bounds.

The slice should add sealed, independently hashable records in a new component
module: `EquationIRV4` (strong form and term provenance), `WeakResidualIRV4`
(test function, integration-by-parts sign, boundary/interface ownership,
source/flux units and nullspace), `DiscreteResidualV4` (mesh/basis/quadrature,
DOF ordering, element/face maps, orientation, conservative flux, residual
scales, Jacobian sparsity and nullspace), and `SolverPlanV4` (provider/input
hashes, numerical configuration, tolerances, stopping and failure taxonomy).
The API should be candidate-first, for example:

```text
compile_equation_ir(package::CandidateStatePackageV5, context::GI1AuthorityContextV1, ...)
lower_weak_residual(equation_ir::EquationIRV4, ...)
discretize_residual(weak_ir::WeakResidualIRV4, ...)
build_solver_plan(discrete::DiscreteResidualV4, ...)
```

These names are a proposed seam, not current functions. The new work order owns
the component module, focused fixture and focused test/runner. The shared entry
(`src/FusionConceptAI.jl`, `src/RuntimeV4/FusionRuntimeV4.jl`, test manifest and
`SpatialRuntimeV4.jl`) stays with the integration owner. Existing V4 compiler,
manufactured pipeline, spatial loader and historical runs are read-only inputs.

Real input/output for a future run must include a fresh candidate/package,
G1/G2/G3/E0/G-I1A identity and authority snapshots, equation/weak/discrete/
solver hashes, provider manifest, material/boundary/source data, per-grid
residual and solution artifacts, and a same-candidate feedback receipt. A
missing closure, chart/metric, function space, boundary, coefficient domain,
unit conversion, provider match or G3 authority returns `terminal_deferred`;
contradictory typed declarations return `fail_closed`; nonfinite/iteration-limit
execution returns `numerical_fail` or `program_exception` according to the frozen
taxonomy. No fallback to the V4 manufactured provider is legal.

## Required evidence gates and negative controls

Before any physical/provider claim, freeze a protocol containing analytic MMS
solution and source, coefficient profile, grids, units/scales and tolerances.
For three nested serial grids, every run must retain solver exit and artifacts,
relative L2 and Linf solution error, discrete residual norm, boundary error,
source/integral balance, and mesh-refinement order. The positive gates are:

1. independent strong residual versus independently assembled weak/discrete
   residual, with a recorded equivalence defect;
2. MMS relative L2/Linf, residual and boundary error thresholds on all grids,
   plus a frozen refinement order range;
3. conservation/source integral balance and interface flux continuity within
   frozen scaled tolerances;
4. coefficient perturbation changes `equation_hash`, `discrete_hash`,
   `solver_input_hash` and receipt identity while preserving candidate binding;
5. G3 feedback receipt matches candidate, component, subject, solver input,
   residual/defect unit, source id and status, while retaining
   `screen_only`/`terminal_deferred` authority.

The minimum negative-control matrix is:

| Control | Required result |
|---|---|
| missing boundary ownership | `terminal_deferred`/`required_obligation`; no solver call |
| negative or non-SPD `K` | `fail_closed`; no provider/solver call |
| wrong source or residual unit | `fail_closed` |
| duplicate/conflicting boundary | `fail_closed` |
| foreign candidate, mesh, G1/G2/G3 ref or stale E0/G-I1A context | `fail_closed` |
| label/family/ID rewrite with semantic payload unchanged | same canonical hashes; no route change |
| missing chart, metric, function space or operator capability | `terminal_deferred` |
| missing G3 authority/feedback join | `terminal_deferred`; no physical promotion |
| nonfinite residual, singular system or iteration limit | `numerical_fail` with receipt; never pass |
| pure Neumann without explicit gauge/nullspace | `terminal_deferred` or `fail_closed`; never silently pin/delete an equation |

An independent implementation/formula must assemble the discrete operator or
strong residual for the positive MMS control. A single solver result or
manufactured `LAPLACE(u)-2f` receipt cannot satisfy this gate.

## File ownership and dispatch boundary

The future implementation worker may own only newly assigned equation/lowering
module(s), its focused V5 fixture, focused test/runner and a preparation archive
under its work order. The integration worker alone may edit shared loaders,
exports, package entrypoints and test manifests. The reviewer must be a
different Luna, must hash the worker inputs/outputs, inspect negative controls,
recompute identity joins and verify real process exit/stdout/stderr. Heavy Julia,
Gridap, DESC or full-package execution stays in the serial heavy lane; this
preparation audit does not run it.

Dispatch is formally released only after UP1-04 acceptance as defined above.
Until then this audit is a ready future work order, not an execution acceptance,
and it does not alter R01–R10, provider/mesh/engineering/physical status or the
credible-device count.

