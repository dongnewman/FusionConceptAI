# UP2-01 physical compiler entry audit R4

Verdict: `ready_for_independent_review_no_execution`.

This R4 is a read-only timing correction to the R3 preparation audit after
`independent_review_r3` identified one circular input phrase. Capture-time
state was HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`, and
294 default porcelain status rows. Julia/DESC process enumeration was empty.
R3, the independent review, source/core files, and the protected dirty files
were hash-checked before this write. Only this `entry_audit_r4/` directory is
owned by this revision; R3 and source/core files are unchanged. No Julia or
DESC command was run.

## Actual-A matrix retained from R3

| layer | actual-A finding | UP2-01 consequence |
|---|---|---|
| G1 | `temperature` and `auxiliary` are both `spatial_dimension=0`; equations are generic `balance`, `source`, and `constraint`. There is no candidate-owned `u`, `K(x)`, `f`, or typed `GRAD`/`DIV_OP` law. Evidence: `test/GenomeV5/G1/fixtures.json:19-35`; `src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:99-149`. | Actual A cannot enter `-div(K grad(u))=f`; proposed compiler APIs and manufactured fixtures are not current compiler inputs. |
| G2 | Two 3-D regions, identity chart, Cartesian embedding, scalar H1 space, mixed exterior faces and patches are structurally declared (`test/GenomeV5/G2/fixtures.json:14-40`). Mesh and physical admission remain `not_executed`; mesh may remain `declared_pending` (`src/GenomeV5/G2/FieldSpacePlanV2.jl:67-95`; `src/GenomeV5/G2/FieldGeometryGenomeV5.jl:217-230`). | Metric, executable mesh/basis/quadrature, face orientation, and Dirichlet/Neumann value/ownership receipts are absent. |
| G3 | Feedback channels and target/source refs are structural, but external authority and a dimensioned source law are absent (`test/GenomeV5/G3/fixtures.json:105-107`; `src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:53-91`; `test/GenomeV5/UP1-04/up1_04a_integration_tests.jl:79-88`; `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json:1-19`). | No authoritative same-candidate source/target/unit/solver receipt join exists; missing source authority remains typed `terminal_deferred`. |

## Existing V4 boundary

`src/RuntimeV4/Compiler.jl:102-156` exposes only the V4
`CandidateStatePackageV4` structural prefix. The exact
`LAPLACE(u)-2f` path in `src/RuntimeV4/FieldResidualPipeline.jl:334-431` is a
`manufactured_control` screen and the provider at lines 522-536 is
`screen_only`. `FieldProgramEvaluation.jl:11-14` leaves `GRAD`, `DIV_OP`,
`CURL`, `LAPLACE`, and `DT` deferred. The standalone provider is two 1-D
uniform-mesh regions with scalar constant conductivity
(`src/RuntimeV4/MultiRegionDiffusionProvider.jl:229-290`). It does not establish
candidate-owned 3-D variable-coefficient compilation or physical evidence.

`EquationIRV4`, `WeakResidualIRV4`, `DiscreteResidualV4`, `SolverPlanV4`, and
the proposed `compile_equation_ir`/`lower_weak_residual`/
`discretize_residual`/`build_solver_plan` names remain future API seams. They
are not current executable entries.

## Corrected acyclic preparation and execution order

The three upstream work orders are schema/profile preparation for the accepted
UP1/UP2-00 contracts. Their declarations are frozen before creating the new
candidate lineage. They do not claim UP2-01 execution success.

1. Start from the accepted UP1-04A limited package and completed contract-only
   UP2-00 preparation available at this stage. Freeze the versioned
   `UP2-01-G1-DIFFUSION-V1`, `UP2-01-G2-METRIC-BOUNDARY-V1`, and
   `UP2-01-G3-SOURCE-FEEDBACK-V1` schema/profile declarations, including their
   input/output/version/hash recipes. If any declaration lacks actual source
   authority, emit and retain a typed `terminal_deferred` record; do not
   fabricate authority or promote the declaration.
2. Create a fresh actual candidate only after those three declarations are
   frozen. Rebuild and hash the G1/G2/G3 references, candidate package, E0
   bound-input, G-I1A authority context, E1/E2 identity/evidence contexts, and
   all UP2 source/identity receipts for this candidate. R2/R3 or other old
   receipts are historical evidence only and cannot be attached or have their
   hashes rewritten.
3. Freeze that new candidate's formal UP1-04B inputs: B00 F0-F5, B04 N01-N10,
   checker version, candidate/component hashes, and two-process replay recipe.
4. Execute and independently review UP1-04B with fresh B00/B04 receipts. Only
   after that acceptance may the full UP1-04 migration/package join complete
   as UP1-04.
5. Keep complete UP1-04 as the hard gate. Only then may UP2-01 release the
   compiler execution dispatch for the new candidate lineage.

This ordering removes the R3 phrase “fresh actual candidate after UP1-04” from
the upstream inputs. UP1-04 is the final gate after the new candidate's
UP1-04B evidence, while the three upstream declarations are frozen before that
candidate and before B00/B04. No old receipt or old hash may be reused.

## Versioned upstream work orders

### `UP2-01-G1-DIFFUSION-V1`

Input: the accepted UP1-04A package and completed UP2-00 contract-only
validator context, before formal UP1-04B; the G1 V5 grammar/profile; and a
typed declaration for scalar `u`, positive scalar `K(x)`, source `f`, typed
`GRAD`/`DIV_OP`, `-div(K grad(u))=f`, units, closure, conservation occurrences,
applicability bounds, and provider capability. This is a pre-freeze schema
input, not an after-UP1-04 candidate.

Output: a versioned G1 contract/profile revision, canonical equation,
coefficient and source hashes, typed lowering receipt, identity recipe, and
source-derived negative classifications for missing operator, wrong units,
nonpositive K, and undeclared closure. Exit only when the declaration is
candidate-bindable and hashes are reproducible; missing authority remains
typed `terminal_deferred`, and contradiction is `fail_closed`.

### `UP2-01-G2-METRIC-BOUNDARY-V1`

Input: the frozen G1 schema/profile plus the G2 3-D chart/regions, explicit
metric/coordinate map, scalar function space, executable mesh/basis/quadrature,
face orientation, and Dirichlet or Neumann face value/ownership. After all
three schemas are frozen, these inputs are bound to the newly created actual
candidate in step 2.

Output: a versioned G2 plan and geometry/metric/mesh/boundary hashes,
candidate-bound execution status, face ownership/orientation receipt, and a
typed deferred receipt when metric, mesh, quadrature, or boundary authority is
absent. Structural chart/patch presence alone cannot pass this gate.

### `UP2-01-G3-SOURCE-FEEDBACK-V1`

Input: frozen G1/G2 schema/profile refs, then the newly rebuilt candidate's
G1/G2 refs and hashes; source/return/heat/ledger law; feedback target; source
ID; units; owner scope; and external authority.

Output: a versioned source-law and feedback-binding hash, same-candidate
target/source/unit/authority receipt, and a schema joining residual, defect,
and solver-input receipts. Missing N05/N06 or external source authority is
typed `terminal_deferred`; contradiction is `fail_closed`.

Each work order carries candidate URI when bound, component refs, version axes,
source paths, exact input/output hashes, and failure taxonomy. The work orders
are not evidence that a provider, mesh, compiler, or physical law already
exists.

## Identity, rebuild, and dispatch gates

The three declarations must be frozen before formal UP1-04B B00/B04. Any
revision to G1, G2, or G3 requires a new candidate and recomputation of package,
E0, G-I1A, E1/E2, component refs, upstream receipts, and all affected UP2
hashes before B00/B04 inputs are frozen. Old candidate receipts remain
historical and cannot be reused or back-filled.

The formal dependency remains: UP2-00 must progress beyond its limited N01/N02
slice; the new candidate must complete fresh UP1-04B B00 F0-F5 and 50 B04
mutation receipts with checker and two-process replay plus independent review;
the full V5 package join must then be accepted as UP1-04; only after that is
UP2-01 compiler execution eligible. This R4 changes no task manifest, DAG, or
R01-R10 parent goal.

## Future variable-coefficient diffusion slice and evidence gates

After the gate, the smallest executable slice is one actual V5 package with a
scalar `u`, positive scalar `K(x)`, source `f`, one bounded Cartesian 3-D
region, executable metric/mesh/function-space, and explicit Dirichlet or
Neumann ownership. It must produce independently hashed equation,
weak-residual, discrete-residual, and solver-plan records for
`-div(K grad(u))=f`.

Required positive evidence is independent strong versus weak/discrete residual
equivalence; three nested serial-grid MMS L2/Linf/residual/boundary errors with
frozen refinement order; source/integral balance and interface flux continuity;
coefficient perturbation changes to equation/discrete/solver hashes; and a
same-candidate G3 feedback receipt carrying units, refs, hashes, status, and
failure taxonomy. Negative controls retain deferred or fail-closed behavior
for missing metric/boundary/authority, nonpositive or non-SPD K, wrong units,
foreign candidate/mesh/context, identity rewriting, nonfinite or iteration
failure, and pure Neumann without an explicit nullspace.

Conclusion: the sole R3 ordering defect is corrected. This is ready for a
different Luna independent review, with no execution dispatch, source/core
mutation, provider credit, mesh credit, physical credit, or parent-goal change.
