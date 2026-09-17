# AD-28 independent static review R1

Verdict: `changes_requested`.

AD-28 is substantively sound as an architecture and preparation proposal. The
three new G1/G2/G3 work orders contain inputs, outputs, writable-file scopes,
version/hash requirements, and exit gates. `UP1-04A-VNEXT` creates the fresh
candidate and rebuilds the complete identity chain. The machine DAG is
acyclic, new nodes remain `planned`/`proposal` with `accepted=false`, and the
actual-A, physical, provider, mesh, and R01-R10 ceilings remain closed.

Two documentation synchronization defects prevent a limited architectural
pass. The current README still contains an earlier unqualified execution-chain
statement omitting `UP1-04A-VNEXT`, while its new AD-28 section gives the
VNEXT DAG. Core16 also calls UP2-00 “当前 ready” even though the machine
manifest keeps it `planned`, `scope_status=accepted_limited`,
`accepted=false`, and the total gate `review_pending`. These can be historical
or shorthand, but they are not marked that way and conflict with the requested
core/machine consistency.

This review is static and read-only at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`. Julia and DESC
were not run. No author file, core file, source, old evidence, or protected
dirty file was changed. The only files written are the four files in this
`independent_review_r1/` directory. Claim ceiling:
`architecture_and_preparation_boundary_only_no_execution_no_provider_mesh_physical_or_R01-R10_credit`.

## Findings that pass

The three versioned upstream work orders are complete preparation boundaries:

| work order | inputs | outputs and exit boundary | file ownership |
|---|---|---|---|
| `UP2-01-G1-DIFFUSION-V1` | Accepted UP1-01/02/03 contract scope plus candidate-owned 3-D `u`, positive `K(x)`, `f`, typed `GRAD/DIV`, units, closure, applicability and negative controls. | Versioned profile, equation/coefficient/source hashes, typed receipt and negative classifications; missing authority `terminal_deferred`, contradiction `fail_closed`, no compiler or physical credit. | Only G1 schema/profile, typed receipt contract, fixture/QA/archive; no old V4, old evidence, UP1-04B suite or physical backend. |
| `UP2-01-G2-METRIC-BOUNDARY-V1` | Chart, metric, mesh, basis/quadrature, face orientation and executable boundary value/ownership declarations. | Versioned plan, geometry/metric/mesh/boundary hashes and face receipt; structural chart alone cannot pass. | Only G2 schema/profile, typed receipt contract, fixture/QA/archive; no old V4/evidence, UP1-04B suite or mesh backend. |
| `UP2-01-G3-SOURCE-FEEDBACK-V1` | Source/return/heat/ledger law, feedback target, source ID, units, owner scope and external authority. | Source-law/feedback hash and same-candidate authority receipt; missing authority `terminal_deferred`, contradiction `fail_closed`. | Only G3 schema/profile, typed receipt contract, fixture/QA/archive; no old V4/evidence, UP1-04B suite or physical backend. |

The `UP1-04A-VNEXT` node has the right ownership and exit boundary: it depends
on old limited UP1-04A plus all three frozen declarations, creates a fresh
actual candidate, rebuilds all G1/G2/G3 public refs and hashes, axes, package,
E0, G-I1A, E1/E2 and UP2 identity/receipt artifacts, and forbids old receipt
or hash reuse. It remains `planned`/`proposal`/`accepted=false` with no UP1-04
or UP2-01 credit.

The machine DAG and core16 work-order dependencies agree on the intended route:

`UP1-01/02/03 → {G1, G2, G3} → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01`.

UP2-00 remains a total gate after VNEXT; UP1-04B still requires B00 F0-F5,
50 fresh B04 receipts, checker, two-process replay and independent review;
complete UP1-04 remains the UP2-01 execution gate. Old accepted_limited local
receipts remain historical for their original candidate. AD-28 does not shrink
R01-R10 or promote any physical/provider/mesh claim.

## Actual-A and implementation boundaries remain unchanged

The R2/R3/R4 audit chain is preserved. Actual A still has G1
`temperature`/`auxiliary` with `spatial_dimension=0`, no candidate-owned
`u/K(x)/f` or typed `GRAD/DIV`; G2 has structural 3-D chart/boundary
declarations but no executed metric/mesh/face ownership; and G3 feedback lacks
external authority and a dimensioned source law. Missing authority remains
`terminal_deferred`. The current N06 fixture is the 1451-byte
`779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` file
recorded by AD-28.

V4 `LAPLACE(u)-2f` remains a manufactured screen. Proposed Equation IR,
weak/discrete residual and SolverPlan names remain future seams. AD-28 grants
no compiler, provider, mesh, solver, engineering, physical or R01-R10 credit.

## Required core-document corrections

1. Mark the earlier README execution chain as the historical/pre-AD28 baseline,
   or update it to include `UP1-04A-VNEXT`; retain the AD-28 new machine DAG as
   the authoritative route.
2. Replace or qualify core16’s “UP2-00 当前 ready” wording so it agrees with
   `task_manifest.json`: `planned`, total `review_pending`,
   `accepted=false`, with only scoped `accepted_limited` local evidence.
3. Rerun `validate_plan.py`, JSON/DAG checks, and core/manifest hash capture
   after those wording changes. Keep AD-28 `proposal`/`review_pending` and all
   new nodes `accepted=false` until a different Luna review and Sol decision.

After these synchronization corrections, AD-28 can receive a limited pass for
architecture and preparation only. This review does not authorize code or
runtime execution and does not change any old evidence or parent goal.

