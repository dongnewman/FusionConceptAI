# UP2/UP3 declared spatial composition V1

## Scope

This additive slice implements a declared one-dimensional variable-
coefficient finite-volume operator, a conservative old-2-cell to new-4-cell
measure-overlap transfer, and typed-port unique-producer edge generation.  The
edges are part of the execution input: the accepted positive path assembles
and solves one 4-by-4 joint matrix/RHS.  No registry, old module, provider,
mesh backend, DESC path, or trusted external receipt is used.

## Python-only evidence

`independent_oracle.py` and `static_qa.py` were run.  Julia/DESC were not run,
as required for this local handoff.

The Python static pass also performs conservative Julia block and delimiter
checks over both source and focused test; both currently report `balanced` with
no unclosed blocks or mismatched `()[]{}`.

- transfer state: `(0.25, 0.25, 0.75, 0.75)`; total conservation residual `0`
- representative K/source/Dirichlet assembly RHS: `(0.25, 0, -0.125, 6.5875)`
- independent solution: `(0.17006478658536583, 0.3782869664634146, 0.5402375508130081, 0.8362471417682926)`
- independent MMS refinement order: `2.0020872428184697` (`>=1.8`)
- declared gates: interface flux residual `0`, ledger residual `0`, one joint solver invocation, zero provider calls
- typed edge payloads/magnitudes drive effective source, boundary values, coupling gain, matrix and RHS; they are not hash-only metadata
- left/right interior-face reconstructions use independently recovered face values and K-side distances; Neumann boundary values enter the assembled RHS
- canonical `semantic_view`/`canonical_hash` methods and K/source hash revalidation reject mutated or forged field declarations
- an independent holdout (`K=[2,0.75,1.4,2.2]`, Dirichlet `(0.2,-0.4)`) produces solution `(0.15601849765681325, 0.01194048906512854, -0.21296590148316002, -0.3486531796880121)` without candidate identity or branch
- the pure-Neumann negative uses matching typed boundary payload `(0,0)`, so payload validation passes and the product path reaches `numerical_fail/pure_neumann_singular`
- negative vectors: duplicate producer, unit mismatch, missing boundary, nonoverlap, nonfinite K, pure Neumann singular, missing return, geometry-hash change

The Julia focused test is included but remains unexecuted in this handoff.  It
covers label/component ordering erasure, two K/BC groups with different hashes
and values, the numerical gates, and all negative vectors above.

## Evidence ceiling and gaps

The result is `screen_only`, `accepted=false`, with no UP credit, R credit, or
L4 credit.  The slice is software/numerical evidence only; no physical,
provider, engineering, candidate, or whole-device authority is claimed.

## Files

- `src/RuntimeV4/DeclaredSpatialCompositionExecutionV1.jl`
- `test/RuntimeV4/DeclaredSpatialComposition/declared_spatial_composition_execution_v1_tests.jl`
- `test/RuntimeV4/DeclaredSpatialComposition/fixture.json`
- `test/RuntimeV4/DeclaredSpatialComposition/independent_oracle.py`
- `test/RuntimeV4/DeclaredSpatialComposition/static_qa.py`
