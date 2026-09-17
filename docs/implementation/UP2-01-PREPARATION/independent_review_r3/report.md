# UP2-01 entry audit R3 independent review

Verdict: `changes_requested`.

R3 incorporates the R2 correction on actual-A evidence and substantially
improves the three upstream work-order contracts. The actual-A matrix, the V4
manufactured-screen boundary, the identity requirements, and the complete
UP1-04 dependency gate are supported. One dispatch-blocking ordering defect
remains: the G1 work order says its input is a fresh candidate *after
UP1-04*, while the same R3 requires all three upstream revisions to be frozen
before formal UP1-04B B00/B04. The planning contract says complete UP1-04 is
itself after UP1-04B and is the UP2-01 prerequisite. Those statements cannot
all be true for one candidate lineage.

This is a static, read-only review at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`. Julia and DESC
were not run. No source, core contract, R2/R3 author audit, or protected dirty
file was changed. The only files written by this review are the four files in
this `independent_review_r3/` directory. Claim ceiling:
`preparation_static_independent_review_no_Julia_DESC_no_core_change_no_provider_or_physical_credit`.

## Findings that pass

R3 now states the actual-A facts required by R2:

| layer | static finding | consequence |
|---|---|---|
| G1 | `temperature` and `auxiliary` are both `spatial_dimension=0`; the equations are generic `balance`, `source`, and `constraint`. Actual A has no candidate-owned scalar `u`, coefficient `K(x)`, source law `f`, or typed `GRAD`/`DIV_OP` expression (`test/GenomeV5/G1/fixtures.json:19-35`; `src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:99-149`). | Actual A cannot enter `-div(K grad(u))=f`; a proposed API or manufactured fixture is not a current compiler input. |
| G2 | The fixture has two structural 3-D regions, an identity chart, Cartesian embedding, scalar H1 space, and exterior faces/patches (`test/GenomeV5/G2/fixtures.json:14-40`). Mesh and physical admission remain `not_executed`; mesh execution defaults to `declared_pending` (`src/GenomeV5/G2/FieldSpacePlanV2.jl:67-95`; `src/GenomeV5/G2/FieldGeometryGenomeV5.jl:217-230`). | The chart/boundary declarations provide no executed metric, mesh, quadrature, face orientation, or Dirichlet/Neumann ownership/value receipt. |
| G3 | Feedback channels and target/source references are structural, but the binding retains `feedback_authority_gap`; the A integration and N06 fixture preserve the provenance/dimensioned-law gap (`src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:53-91`; `test/GenomeV5/UP1-04/up1_04a_integration_tests.jl:79-88`; `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json:1-19`). | No authoritative same-candidate source/target/unit/solver receipt join exists. |

R3 also preserves the V4 boundary. `Compiler.jl` has only the V4
`CandidateStatePackageV4` structural prefix; the field pipeline is the sealed
manufactured `LAPLACE(u)-2f` screen; derivative operators remain deferred; and
the standalone diffusion provider is a two-region, one-dimensional,
constant-conductivity uniform-mesh provider. The proposed Equation/weak/
discrete/SolverPlan names remain future API seams. None is real variable-
coefficient compilation or physical evidence.

The three work orders contain the right substantive fields for preparation:

1. `UP2-01-G1-DIFFUSION-V1` covers candidate-owned `u`, positive `K(x)`,
   `f`, typed `GRAD`/`DIV_OP`, units, closure, conservation occurrences,
   applicability, provider capability, hashes, candidate identity, and
   negative classifications.
2. `UP2-01-G2-METRIC-BOUNDARY-V1` covers the chart/metric/function space,
   executable mesh/basis/quadrature, face orientation and boundary ownership,
   candidate-bound geometry hashes, and deferred execution.
3. `UP2-01-G3-SOURCE-FEEDBACK-V1` covers source/return/heat/ledger law,
   feedback target, source ID, units, external authority, same-candidate
   joins, hashes, and deferred/fail-closed outcomes.

## Required ordering correction

The current R3 wording is circular:

- R3 gives the G1 work order an input of “a fresh actual candidate after
  UP1-04”.
- R3 then requires the three upstream revisions to be frozen before formal
  UP1-04B B00/B04.
- The execution plan makes complete UP1-04 depend on UP1-04B, and makes
  complete UP1-04 the UP2-01 prerequisite (`docs/v4_multitopology_generation/16_execution_work_orders.md:302-305`,
  `:234-265`).

The author audit must replace the G1 input phrase with a pre-freeze context,
for example: “the accepted UP1-04A package and completed UP2-00 contract-only
validator, before formal UP1-04B, plus a candidate context created only after
the three upstream schemas/profiles are frozen.” The same sequence must be
stated for G2 and G3:

1. Freeze the three versioned upstream schema/profile revisions and their
   input/output/version/hash recipes before creating the B00/B04 candidate
   baseline.
2. Build a fresh candidate from those frozen revisions and recompute its
   package, E0 bound-input, G-I1A context, component refs, and candidate
   identity. Do not reuse R2 or historical receipts.
3. Freeze the formal UP1-04B B00 F0-F5 and B04 N01-N10 inputs, candidate hashes,
   checker version, and two-process replay recipe for that candidate.
4. Execute and independently review UP1-04B; only then accept the full UP1-04
   migration/package join.
5. Keep complete UP1-04 as the hard UP2-01 dispatch gate.

The work-order outputs may emit `terminal_deferred` or `fail_closed` records
while inputs are incomplete, but they must not claim a post-UP1-04 candidate
while also being a prerequisite for that candidate's UP1-04B freeze.

## Required evidence gates after the ordering fix

The future one-candidate slice still needs independently hashed equation,
weak-residual, discrete-residual, and solver-plan records for
`-div(K grad(u))=f`; independent strong/weak/discrete equivalence; three-grid
MMS L2/Linf/residual/boundary convergence; source balance and interface flux
continuity; coefficient-perturbation identity changes; and a same-candidate G3
feedback receipt. Missing metric/boundary/authority remains deferred; wrong
units, nonpositive or non-SPD K, foreign identity, and contradictory inputs
remain fail-closed. A V4 manufactured receipt, structural V5 test, or runner
exit cannot satisfy these gates.

After the exact ordering correction, R3 can receive a limited preparation pass
for future dispatch. Until then, `changes_requested` is the appropriate
independent result. This review does not authorize source implementation,
Julia/DESC execution, provider credit, mesh credit, physical credit, or any
change to R01-R10.

