# AD-28 repair R2 independent review

Verdict: `pass_limited` for the architecture and preparation boundary only.

The repair addresses both R1 synchronization findings. README now explicitly
marks the earlier `UP1-01/02/03 → UP1-04A → UP2-00 → UP1-04B → UP1-04 → UP2-01`
route as the historical old-candidate chain and states the authoritative AD-28
route with the three parallel G1/G2/G3 declarations and `UP1-04A-VNEXT`.
Core16 now describes UP2-00 as a planned machine node with a
`review_pending` total gate, `accepted=false`, scoped local
`accepted_limited` slices, and a dependency on VNEXT/new-candidate rebinding.

The repair leaves core18 and `task_manifest.json` byte-identical to their AD28
before/after records. The 31-task machine DAG is acyclic; new AD28 nodes remain
`planned`/`proposal` with `accepted=false`; old accepted_limited scopes,
actual-A gaps, physical/provider/mesh boundaries, and R01-R10 obligations are
unchanged. The current N06 fixture remains a 1451-byte authority-gap file with
`terminal_deferred`; no R4 drift is promoted.

This is a static read-only review at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`. Julia and DESC
were not run. No author, core, source, old evidence, or protected dirty file
was changed. Only the four files in this `independent_review_r2/` directory
were written. Claim ceiling:
`architecture_and_preparation_boundary_only_no_execution_no_provider_mesh_physical_or_R01-R10_credit`.

## Verified repair scope

The three upstream work orders still have explicit inputs, outputs, file
ownership and exit gates. `UP1-04A-VNEXT` remains a proposal-only rebinding
gate that creates a fresh candidate and rebuilds all G1/G2/G3 refs, axes,
package, E0, G-I1A, E1/E2 and UP2 identity/receipt artifacts. Old receipts are
historical only. The intended route remains:

`UP1-01/02/03 → {UP2-01-G1-DIFFUSION-V1, UP2-01-G2-METRIC-BOUNDARY-V1, UP2-01-G3-SOURCE-FEEDBACK-V1} → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01`.

UP2-00’s local `accepted_limited` evidence remains separate from its total
`review_pending` gate. UP1-04B still owns fresh B00 F0-F5, all 50 formal B04
receipts, checker and two-process replay. Complete UP1-04 remains the UP2-01
execution gate. The repair grants no compiler, provider, mesh, engineering,
physical or R01-R10 credit.

Actual A remains unchanged: G1 has only 0D `temperature`/`auxiliary` and no
candidate-owned `u/K(x)/f`; G2 has structural chart/boundary declarations but
no executable metric/mesh/face ownership; G3 lacks external feedback/source
authority. Missing authority remains `terminal_deferred`, and V4
`LAPLACE(u)-2f` remains a manufactured screen.

The limited pass covers only the repaired documentation synchronization and
architecture/preparation semantics. It does not authorize implementation,
runtime execution, physical promotion, or a change to the parent goal.

