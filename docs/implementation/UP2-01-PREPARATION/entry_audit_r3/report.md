# UP2-01 physical compiler entry audit R3

Verdict: `ready_for_independent_review_no_execution`.

This R3 is a read-only revision of the R2 preparation audit after the
independent R2 review requested explicit actual-A evidence. Capture-time state
was HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`, and 294
porcelain status rows before R3 files were created. The final inventory also
reports 294 rows because the untracked R3 files are aggregated under the
existing dirty inventory; the R3 paths are explicitly present in the
post-capture listing. The initial and final process sweeps were empty. R2 and
all source/core/protected files retain their recorded hashes. No Julia or DESC
command was run. Only this `entry_audit_r3/` directory is written.

## Actual-A entry matrix

The accepted limited A fixtures are not the requested diffusion candidate.

| layer | actual-A observed input | UP2-01 consequence |
|---|---|---|
| G1 | States are `temperature` and `auxiliary`, both `spatial_dimension=0`; equations are generic `balance`, `source`, and `constraint`. There is no candidate-owned scalar `u`, coefficient field `K(x)`, source law `f`, or typed `GRAD`/`DIV_OP` expression. Evidence: `test/GenomeV5/G1/fixtures.json:19-35`; the A projection only projects concrete N01/N02 fields and leaves other registered fields pending (`src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:99-149`). | No actual-A declaration can enter `-div(K grad(u))=f`; a proposed compiler function or manufactured fixture cannot be counted as the current entry. |
| G2 | Two 3-D regions, identity `(x,y,z)` chart, Cartesian embedding, scalar H1 space, mixed exterior faces and patches are structurally declared (`test/GenomeV5/G2/fixtures.json:14-40`). `G2MeshPlanV2` permits `declared_pending`; admission reports mesh and physical status `not_executed` (`src/GenomeV5/G2/FieldSpacePlanV2.jl:67-95`; `src/GenomeV5/G2/FieldGeometryGenomeV5.jl:217-230`). | Useful structural geometry only. `FieldSpacePlanV2` has no metric member, and field evaluation records `g2_coordinate_map_unexecuted` and `g2_metric_unexecuted` (`src/GenomeV5/G2/FieldSpacePlanV2.jl:173-198`; `src/RuntimeV4/FieldProgramEvaluation.jl:351-355`). No executable mesh, face orientation, or Dirichlet/Neumann value/ownership receipt exists. |
| G3 | Feedback channels are structurally present with G1/G2 target refs and source IDs (`test/GenomeV5/G3/fixtures.json:105-107`), but the binding retains `feedback_authority_gap` and A retains the provenance gap (`src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:53-91`; `test/GenomeV5/UP1-04/up1_04a_integration_tests.jl:79-88`). The actual-A dimensioned-law fixture has `actual_a_positive=false` and expects `dimensioned_law_missing`/`terminal_deferred` (`test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json:1-19`). | No source law, same-candidate residual/source/target/unit/solver receipt join, or feedback authority exists; physical promotion remains forbidden. |

Thus actual A has structural G2 chart/boundary declarations and structural G3
feedback channels, while candidate-owned G1 `u/K(x)/f`, executable G2
metric/mesh/face ownership, G3 dimensioned source law, and external feedback
authority are absent or deferred.

## Existing V4 boundary

`src/RuntimeV4/Compiler.jl:102-156` exposes only
`compile_candidate(::CandidateStatePackageV4, ...) → CompiledCandidatePrefixV4`
structural obligations. The exact V4 manufactured path in
`src/RuntimeV4/FieldResidualPipeline.jl:334-431` accepts only sealed
`LAPLACE(u)-2f` and labels the evidence `manufactured_control`; its provider at
lines 522-536 is `screen_only`. `FieldProgramEvaluation.jl:11-14` leaves
`GRAD`, `DIV_OP`, `CURL`, `LAPLACE`, and `DT` deferred. The standalone diffusion
provider has one scalar constant `conductivity::Float64` and scalar source per
region and assembles two 1-D uniform-mesh regions
(`src/RuntimeV4/MultiRegionDiffusionProvider.jl:229-290`). It cannot provide
candidate-owned 3-D `K(x)` or a general conservative flux path. The V4
manufactured screen is retained as a regression control only.

The proposed `EquationIRV4`, `WeakResidualIRV4`, `DiscreteResidualV4`,
`SolverPlanV4`, and `compile_equation_ir`/`lower_weak_residual`/
`discretize_residual`/`build_solver_plan` names in R2 remain future API seams;
none is a current executable entry point or evidence of implementation.

## Versioned upstream work orders required before compiler dispatch

These are preparation-level work-order contracts. They do not change
`task_manifest.json` and do not authorize implementation in this audit.

### `UP2-01-G1-DIFFUSION-V1`

Input: a fresh actual candidate context after UP1-04, the G1 V5 grammar/profile,
and a typed declaration for scalar `u`, positive scalar `K(x)`, source `f`,
`GRAD`/`DIV_OP`, `-div(K grad(u))=f`, residual/source units, closure and
conservation-account occurrences, applicability bounds, and provider
capability. Output: a versioned G1 contract/profile revision, canonical equation
and coefficient/source hashes, typed lowering receipt, candidate identity, and
source-derived negative classifications for missing operator, wrong units,
nonpositive K, and undeclared closure. Exit only when all values are
candidate-owned and hashes are reproducible; otherwise preserve
`terminal_deferred` or `fail_closed`.

### `UP2-01-G2-METRIC-BOUNDARY-V1`

Input: the fresh G1-bound candidate plus G2 3-D chart/regions and an explicit
metric/coordinate map, scalar function space, executable mesh/basis/quadrature,
face orientation, and Dirichlet or Neumann face value/ownership. Output: a
versioned G2 plan and geometry/metric/mesh/boundary hashes, candidate-bound
execution status, face ownership/orientation receipt, and a deferred receipt
when metric, mesh, quadrature or boundary authority is absent. Exit only when
the geometry is executable by the declared profile; structural chart/patch
presence alone is insufficient.

### `UP2-01-G3-SOURCE-FEEDBACK-V1`

Input: fresh G1/G2 refs and hashes plus G3 source/return/heat/ledger law,
feedback target, source ID, units, owner scope and external authority. Output:
a versioned source-law and feedback-binding hash, same-candidate target/source/
unit authority receipt, and a schema for joining residual/defect/solver-input
receipts. Exit only with exact candidate/ref/hash/source/unit closure; missing
N05/N06 or external authority remains `terminal_deferred`, and contradiction is
`fail_closed`.

Each work order must retain its own typed input/output hashes, candidate URI,
component hashes, version axes, source paths and failure taxonomy. No fixture
label, synthetic ref, or equality of untrusted values may supply authority.

## Identity and dependency rule

The three upstream revisions must be frozen before formal UP1-04B execution.
After any G1/G2/G3 revision, the integration owner must rebuild an actual
candidate and recompute its package, E0 bound-input, G-I1A context, upstream
component, and all affected UP2 receipts/hashes. Old candidate receipts may be
retained as historical evidence but cannot be attached to the revised
candidate. Reuse after the old receipts would break candidate ownership and is
not an admissible dispatch path.

Formal UP2-01 execution dispatch remains behind complete UP1-04: UP2-00 must be
accepted beyond its limited N01/N02 slice; UP1-04B must complete fresh B00
F0-F5 and 50 B04 mutation receipts, checker and two-process replay with
independent review; then the full V5 package join must be accepted. This R3
does not alter that DAG or R01-R10.

## Future compiler slice and evidence gates

Once the upstream work orders and UP1-04 gate are complete, the finite slice is
one actual V5 package with one scalar `u`, one positive scalar `K(x)`, one `f`,
one bounded Cartesian 3-D region, one executable metric/mesh/function-space,
and one explicit Dirichlet or Neumann boundary. It must lower
`-div(K grad(u))=f` through four independently hashed records: equation, weak
residual, discrete residual, and solver plan. Required positive evidence is
independent strong versus weak/discrete residual equivalence; three nested
serial-grid MMS L2/Linf/residual/boundary errors and frozen refinement order;
source/integral balance and interface flux continuity; coefficient perturbation
changes to equation/discrete/solver hashes; and a same-candidate G3 feedback
receipt carrying units, refs, hashes, status and failure taxonomy.

Required negative controls are missing boundary or metric (`terminal_deferred`,
zero solver calls), nonpositive/non-SPD K or wrong units (`fail_closed`),
foreign candidate/mesh/ref/context (`fail_closed`), missing G3 authority
(`terminal_deferred`), label/family/ID rewrite (canonical hashes unchanged),
nonfinite/iteration limit (`numerical_fail` or `program_exception`), and pure
Neumann without explicit nullspace (`terminal_deferred` or `fail_closed`).

Conclusion: the R2 corrections are incorporated and the preparation package is
ready for independent review, with no execution dispatch, source mutation,
provider claim, mesh claim, physical claim or parent-goal change.
