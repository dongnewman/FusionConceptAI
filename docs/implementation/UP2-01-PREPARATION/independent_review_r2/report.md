# UP2-01 entry audit R2 independent review

Verdict: `changes_requested` for the submitted `entry_audit_r2` report, with a
limited pass on its baseline, dependency, and current V4 source findings.

This is an independent, read-only review of
`docs/implementation/UP2-01-PREPARATION/entry_audit_r2/` at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The review did not run Julia or
DESC and did not change source, core contracts, the original audit, or any
protected dirty file. The only files written by this review are the four files
in this `independent_review_r2/` directory. Claim ceiling:
`preparation_static_independent_review_no_Julia_DESC_no_core_change_no_provider_or_physical_credit`.

## What passes in the submitted audit

The submitted audit correctly keeps `UP2-01` planned behind `UP1-04`, records
`UP1-04A` as limited contract-only work, keeps the total `UP2-00` gate open,
and leaves `UP1-04B` planned. Its conclusion that the current `Compiler.jl`
is a V4 structural-prefix compiler, that the field pipeline is the exact
manufactured `LAPLACE(u)-2f` screen, and that the standalone diffusion provider
is not a candidate-owned 3-D provider is supported by the current source.

The baseline is reproducible: branch `main`, HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, 294 porcelain status rows before
this review, all six protected dirty hashes match the submitted manifest, and
the initial/final process sweeps were empty. The planning validator, JSON parse,
`git diff --check`, and a fresh 33-file SHA256 recheck all exited successfully.

These checks support only the preparation claim ceiling. They do not release
dispatch and do not provide B00/B04, provider, mesh, numerical, engineering,
physical, or R01-R10 credit.

## Required correction: audit the actual A package separately from type presence

The submitted report lists generic G1/G2/G3 V5 types, but does not explicitly
state what the actual A package built by the accepted fixtures contains. That
distinction is required for this entry decision. The static source-backed
matrix is:

| actual-A input | observed state | UP2-01 consequence |
|---|---|---|
| G1 `u`, candidate-owned `K(x)`, and source `f` | Absent. The actual-A construction uses G1 fixture states `temperature` and `auxiliary`, both with `spatial_dimension=0`; its equations are generic `balance`, `source`, and `constraint`, with no gradient/divergence law or coefficient field (`test/GenomeV5/G1/fixtures.json:19-35`). The A projection only populates N01/N02 from concrete fields; other registered fields remain typed pending (`src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:99-149`). | No declaration-driven `-div(K grad(u))=f` compiler input exists. A proposed function or fixture cannot be counted as the current entry. |
| G2 3-D chart and boundary geometry | Present structurally. The actual G2 fixture declares two 3-D regions, an identity `(x,y,z)` chart, Cartesian embedding, scalar H1 space, mixed exterior faces and patches (`test/GenomeV5/G2/fixtures.json:14-40`). | This is contract geometry only. `G2MeshPlanV2` defaults to `declared_pending`; G2 admission reports `mesh_status=:not_executed` and `physical_status=:not_executed` (`src/GenomeV5/G2/FieldSpacePlanV2.jl:67-95`; `src/GenomeV5/G2/FieldGeometryGenomeV5.jl:217-230`). |
| G2 metric and executable boundary ownership | Missing as an executable input. `FieldSpacePlanV2` has chart, embedding, field space, mesh and exterior, but no metric member (`src/GenomeV5/G2/FieldSpacePlanV2.jl:173-198`). Field evaluation records `g2_coordinate_map_unexecuted` and `g2_metric_unexecuted` (`src/RuntimeV4/FieldProgramEvaluation.jl:351-355`). The mixed exterior/patch declarations do not supply a solver-bound Dirichlet/Neumann value and ownership receipt. | The current package cannot lower a spatial derivative or assemble a boundary flux. |
| G3 feedback and source law | Feedback channels are structurally present with G1/G2 targets and source IDs (`test/GenomeV5/G3/fixtures.json:105-107`), but their fixture targets require external authority. The binding retains `feedback_authority_gap` even when supplied refs compare equal (`src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:53-91`), and UP1-04A records `feedback_provenance_gap` (`test/GenomeV5/UP1-04/up1_04a_integration_tests.jl:79-88`). The actual-A dimensioned-law fixture explicitly sets `actual_a_positive=false` and expects `dimensioned_law_missing`/`terminal_deferred` (`test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json:1-19`). | No same-candidate residual/source/target/units/solver receipt can be joined to G3 feedback; no physical promotion is legal. |

Thus the accurate actual-A statement is: G2 has a useful 3-D structural chart
and boundary declaration, and G3 has structural feedback channels, but actual A
does not contain candidate-owned `u/K/f`, an executable metric/boundary plan, a
source law, or authoritative feedback closure.

## Source and evidence boundary

`src/RuntimeV4/Compiler.jl:102-156` defines `compile_candidate` only for
`CandidateStatePackageV4` and emits `CompiledCandidatePrefixV4` structural
obligations. There is no V5 Equation IR entry. The exact manufactured path in
`src/RuntimeV4/FieldResidualPipeline.jl:334-431` rejects anything except the
sealed six-node `LAPLACE(u)-2f` form and fixes evidence to
`manufactured_control`; its provider is `screen_only` at lines 522-536.

`src/RuntimeV4/FieldProgramEvaluation.jl:11-14` leaves `GRAD`, `DIV_OP`,
`CURL`, `LAPLACE`, and `DT` deferred. The standalone provider's typed region
specification has one scalar `conductivity::Float64` and one scalar source per
region (`src/RuntimeV4/MultiRegionDiffusionProvider.jl:229-250`), and its solver
assembles exactly two 1-D regions on uniform meshes (`:286-290`). This cannot
represent candidate-owned spatial `K(x)` or a general 3-D conservative flux.

No generic `EquationIRV4`, `WeakResidualIRV4`, `DiscreteResidualV4`, or
`SolverPlanV4` struct is present in the inspected source. Existing regional
weak-residual names are domain-specific slices and are not a declaration-driven
variable-coefficient compiler.

The submitted positive gates are directionally correct but must be evaluated
against the actual-A closure above. A future run must independently demonstrate
strong versus weak/discrete residual equivalence, MMS L2/Linf/residual/boundary
errors on three nested grids, source/integral balance and interface flux
continuity, coefficient perturbation identity changes, and a same-candidate G3
feedback receipt. A V4 manufactured receipt, a structural V5 test, or a runner
exit code cannot satisfy any of those gates.

## Required versioned upstream work orders

Before dispatching the compiler slice, the plan needs explicit upstream Genome
work orders. The following IDs are proposed names for Sol to freeze; this review
does not modify `task_manifest.json`.

1. `UP2-01-G1-DIFFUSION-V1`: add a candidate-bound G1 schema/profile revision
   containing scalar state `u`, positive scalar coefficient field `K(x)`, source
   `f`, the typed `GRAD`/`DIV_OP` expression for
   `-div(K grad(u))=f`, residual/source units, closure and conservation account
   occurrences, applicability bounds, canonical hash, and a fresh candidate
   identity. It must provide one legal profile and negative controls for missing
   operator, wrong units, nonpositive K, and undeclared closure.
2. `UP2-01-G2-METRIC-BOUNDARY-V1`: add a versioned candidate-owned G2 plan
   binding the 3-D chart to an explicit metric/coordinate map, scalar function
   space, executable mesh/basis/quadrature, and explicit Dirichlet or Neumann
   face ownership/value/source. Its output must include plan and geometry hashes,
   mesh status, face orientation, and a deferred result when metric, mesh or
   boundary authority is absent.
3. `UP2-01-G3-SOURCE-FEEDBACK-V1`: add a versioned G3 source/return/heat/ledger
   law and feedback target whose target ref/hash, source ID, units, candidate
   binding and authority are exact. Its output must support a same-candidate
   residual/defect receipt and retain `terminal_deferred` until N05/N06 authority
   is present.

The downstream `UP2-01` work order can then consume these fresh G1/G2/G3 refs
and rebuild E0/G-I1A and all affected identities. It must add four independently
hashed records (equation, weak residual, discrete residual, solver plan), while
keeping the V4 manufactured fixture as a regression control. Any Genome change
invalidates old candidate/provider receipts and requires a fresh candidate and
fresh upstream execution.

## Exact requested changes to the submitted audit

The original audit should be revised to:

- add the actual-A matrix above, including the explicit absence of `u/K/f`, the
  structural-only 3-D G2 chart/boundary, the missing/unexecuted metric, and the
  G3 feedback/source-law authority gap;
- link the actual-A evidence to the fixture/test lines rather than describing
  only generic V5 types;
- list the three versioned upstream Genome work orders and their identity/hash
  outputs before the proposed compiler API;
- preserve the existing claim ceiling and state that the proposed API names and
  `EquationIRV4`/`WeakResidualIRV4`/`DiscreteResidualV4`/`SolverPlanV4` are not
  current executable entry points.

Once those textual corrections are made, the preparation audit can be accepted
as a limited future-dispatch work order. Until then, `changes_requested` is the
appropriate independent review result; no source implementation or Julia/DESC
run is authorized by this review.
