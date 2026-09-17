# AD-28 proposal: acyclic upstream preparation and new-candidate rebinding

Status: `accepted_limited` (architecture, acyclic scheduling and evidence boundary only)  
Accepted: `true` (limited scope only)  
Runtime: not run; Julia/DESC not run

AD-28 records the Sol architecture decision requested for UP2-01 preparation.
It adds three versioned upstream schema/profile work orders and a separate
`UP1-04A-VNEXT` new-candidate rebinding gate. The three upstream declarations
depend only on accepted UP1-01, UP1-02 and UP1-03 and may be prepared in
parallel. `UP1-04A-VNEXT` depends on the three declarations and the historical
limited UP1-04A boundary. The new candidate lineage is then consumed by the
UP2-00 total gate, fresh UP1-04B B00/B04 evidence, complete UP1-04, and only
then UP2-01 compiler dispatch.

The machine DAG is:

```text
UP1-01 ─┬─> UP2-01-G1-DIFFUSION-V1 ─┐
UP1-02 ─┼─> UP2-01-G2-METRIC-BOUNDARY-V1 ─┼─> UP1-04A-VNEXT ─> UP2-00 ─> UP1-04B ─> UP1-04 ─> UP2-01
UP1-03 ─┴─> UP2-01-G3-SOURCE-FEEDBACK-V1 ─┘
                         ↑
                    old UP1-04A
```

`UP1-04A`, its G-I1A/N05/N06/UP2 local receipts, and the current R4 audit are
historical or limited-scope evidence for their original candidate. They are
not formal B00/B04 inputs for the new candidate. Once the three upstream
declarations freeze, the rebinding gate must create a fresh candidate and
recompute all three public refs, component hashes, four axes, package, E0,
G-I1A, E1/E2 and UP2 source/identity receipts. Any later upstream Genome
change invalidates that lineage and requires a new candidate and a fresh
formal 50-row/B00 checker/two-process freeze.

The three work orders are deliberately contract and preparation boundaries:

- `UP2-01-G1-DIFFUSION-V1` declares candidate-owned 3-D `u`, positive `K(x)`,
  `f`, typed `GRAD`/`DIV`, units, closure, applicability and source-derived
  negative controls.
- `UP2-01-G2-METRIC-BOUNDARY-V1` declares chart-to-metric mapping, executable
  mesh/basis/quadrature and executable face orientation/value ownership.
- `UP2-01-G3-SOURCE-FEEDBACK-V1` declares same-candidate source/return/heat/
  ledger law, feedback target, source ID, units, owner scope and authority.

Missing actual authority remains typed `terminal_deferred`; contradictions are
`fail_closed`; unexpected faults are `program_exception`. Current actual A
still has no candidate-owned `u/K(x)/f`, executable metric/mesh/face
ownership, or feedback authority. Documentation cannot fill those gaps. The
V4 `LAPLACE(u)-2f` manufactured path remains a screen only, and proposed
Equation/Weak/Discrete/SolverPlan APIs remain future seams.

AD-28 changes no source, compiler, provider, mesh, solver, physical evidence,
R01-R10 obligation, or parent goal. It grants no UP2-01 execution credit.
Different-Luna R2 review is `pass_limited`, and Sol accepts AD-28 only as this
architecture, acyclic scheduling and evidence boundary. The three upstream
work orders, `UP1-04A-VNEXT`, UP2-00 total, formal B00/B04, complete UP1-04,
UP2-01 compiler/mesh/provider/physical execution and R01-R10 remain
unaccepted.
