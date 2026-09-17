# UP2-01 entry audit R4 independent review

Verdict: `changes_requested`.

R4 corrects the R3 timing defect and states the required acyclic lineage:
freeze the three versioned G1/G2/G3 declarations, create a fresh actual
candidate from those declarations, rebuild every affected identity and
receipt, freeze that candidate's formal UP1-04B B00/B04 inputs, execute and
independently review UP1-04B, accept full UP1-04, and only then release UP2-01
compiler execution. The review does not grant execution, provider, mesh,
numerical, physical, engineering, or R01-R10 credit.

This is a static read-only review at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`. Julia and DESC
were not run. No source, core contract, author audit, prior review, or
protected dirty file was changed. The only files written by this review are
the four files in `independent_review_r4/`. Claim ceiling:
`preparation_static_independent_review_no_Julia_DESC_no_core_change_no_provider_or_physical_credit`.

## Actual-A and V4 boundaries pass

R4 preserves the source-backed actual-A facts from R3:

| layer | verified finding | consequence |
|---|---|---|
| G1 | Actual A has `temperature` and `auxiliary`, both `spatial_dimension=0`, with generic `balance`, `source`, and `constraint` equations. Candidate-owned `u`, `K(x)`, `f`, and typed `GRAD`/`DIV_OP` are absent (`test/GenomeV5/G1/fixtures.json:19-35`; `src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl:99-149`). | Actual A cannot enter `-div(K grad(u))=f`; a proposed API or manufactured fixture is not a current compiler input. |
| G2 | Two 3-D regions, identity chart, Cartesian embedding, scalar H1 space, and exterior faces/patches are structural declarations. Mesh and physical admission remain `not_executed`, with mesh execution allowed to remain `declared_pending` (`test/GenomeV5/G2/fixtures.json:14-40`; `src/GenomeV5/G2/FieldSpacePlanV2.jl:67-95`; `src/GenomeV5/G2/FieldGeometryGenomeV5.jl:217-230`). | Metric, executable mesh/basis/quadrature, face orientation, and boundary value/ownership receipts are absent. |
| G3 | Feedback channels and target/source refs are structural, while external authority and the dimensioned source law remain absent (`test/GenomeV5/G3/fixtures.json:105-107`; `src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl:53-91`; `test/GenomeV5/UP1-04/up1_04a_integration_tests.jl:79-88`; `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json:1-19`). | Missing authority remains `terminal_deferred`; no authoritative same-candidate source/target/unit/solver join exists. |

The V4 boundary is also preserved. `Compiler.jl` only exposes the V4
`CandidateStatePackageV4` structural prefix. `FieldResidualPipeline.jl` is the
sealed `LAPLACE(u)-2f` `manufactured_control` screen, derivative operators in
`FieldProgramEvaluation.jl` remain deferred, and the standalone diffusion
provider is limited to two one-dimensional uniform-mesh regions with scalar
constant conductivity. The proposed Equation/weak/discrete/SolverPlan names
remain future API seams. No V4 receipt is promoted to variable-coefficient
compilation or physical evidence.

## Timing and identity review

The R4 sequence is acyclic and complete:

1. Freeze `UP2-01-G1-DIFFUSION-V1`, `UP2-01-G2-METRIC-BOUNDARY-V1`, and
   `UP2-01-G3-SOURCE-FEEDBACK-V1` as versioned schema/profile preparation.
   Missing source authority emits typed `terminal_deferred`; it cannot be
   fabricated or promoted.
2. Create a fresh actual candidate only after those declarations freeze.
3. Rebuild and hash all G1/G2/G3 refs, the candidate package, E0 bound-input,
   G-I1A authority context, E1/E2 identity/evidence contexts, and all affected
   UP2 receipts and identities.
4. Freeze that new candidate's UP1-04B B00 F0-F5, B04 50 fresh mutations,
   checker version, candidate/component hashes, and two-process replay recipe.
5. Execute and independently review UP1-04B, then complete the full UP1-04
   migration/package join.
6. Release UP2-01 compiler execution only after complete UP1-04.

R4 explicitly makes old receipts and hashes historical only. Any later G1/G2/G3
revision requires a new candidate and a full identity/receipt rebuild before
B00/B04 freeze. This satisfies the R3 correction and keeps candidate ownership
intact. A second static issue prevents acceptance: the R4 evidence manifest
does not match the current dirty-tree N06 fixture. R4 records
`test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` as 1453 bytes with SHA256
`760296eb...`, while the current file is 1451 bytes with SHA256
`779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`. Its
actual-A deferred conclusion remains compatible, but the recorded evidence
identity is stale and must be refreshed before a limited pass.

The three work orders contain the needed preparation contracts:

- G1 declares typed `u`, positive `K(x)`, `f`, `GRAD`/`DIV_OP`, units, closure,
  conservation, applicability, provider capability, hashes, and negative
  classifications.
- G2 declares metric/coordinate map, function space, executable
  mesh/basis/quadrature, face orientation, boundary ownership/value, hashes,
  execution status, and deferred handling.
- G3 declares source/return/heat/ledger law, feedback target, source ID, units,
  external authority, same-candidate joins, hashes, and deferred/fail-closed
  handling.

The formal gates remain closed: UP2-00 is still review-pending beyond its
limited actual-A slice; UP1-04B still needs fresh B00/B04 receipts, checker,
two-process replay, and independent review; full UP1-04 remains pending; and
UP2-01 dispatch remains false. The phrase “completed UP2-00 contract-only
validator context” is therefore treated as an available preparation context,
not as acceptance of the UP2-00 total gate.

## Future evidence boundary

After all gates, a real one-candidate slice must produce independently hashed
equation, weak-residual, discrete-residual, and solver-plan records for
`-div(K grad(u))=f`; independent strong/weak/discrete equivalence; three-grid
MMS L2/Linf/residual/boundary convergence; source balance and interface flux
continuity; coefficient-perturbation identity changes; and a same-candidate G3
feedback receipt. Missing metric, boundary, or authority remains deferred;
wrong units, nonpositive/non-SPD K, foreign identity, contradictions, and
other declared failure cases remain fail-closed or typed numerical/program
failure. These are future gates and are not claimed by this preparation pass.

After the N06 current hash and its source-derived gap classification are
refreshed in the R4 author manifest, the corrected preparation contracts can
receive a limited pass. Until then, `changes_requested` is required for the
evidence identity mismatch. This review does not authorize implementation,
Julia/DESC execution, source mutation, provider or mesh claims, physical
promotion, or a change to R01-R10.
