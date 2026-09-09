# Conservative multi-region execution report — 2026-09-10

## Outcome

Accepted as an isolated manufactured-control implementation candidate after
main-agent review. The slice binds a validated forward context to exact typed
region, interface, source, sink, and boundary ownership; assembles real
off-diagonal interface terms in one global residual; executes and verifies the
global correction; and seals cache/fresh-replay receipts.

This is software and manufactured-control evidence only. It does not supply a
real physical provider, three-dimensional field coupling, physical validation,
engineering feasibility, integrated whole-device closure, or a credible
device candidate.

## Files

- `src/RuntimeV4/ConservativeMultiRegionExecution.jl`
- `examples/runtime_v4_conservative_multiregion_execution.jl`
- `test/runtime_v4_conservative_multiregion_execution_tests.jl`
- `docs/implementation/conservative_multiregion_execution.md`
- `docs/reports/conservative_multiregion_execution_20260910.md`

No aggregator, accepted Gridap/native module, or rejected untracked prototype
is modified.

## Review corrections

Before final qualification, the main review added two fail-closed checks:

1. region ownership must exactly cover all mechanism-graph node identities;
2. plan admission and validation must independently derive every region RHS
   from the exact typed external occurrence values.

The adversarial suite includes a self-consistent forged balance hash whose RHS
does not match its owned occurrences and requires rejection.

## Current-source verification

Focused command:

```text
julia --startup-file=no --history-file=no --project=. test/runtime_v4_conservative_multiregion_execution_tests.jl
```

Result: `117/117`, exit `0`.

| Test group | Result |
|---|---:|
| candidate-bound typed multi-region ownership | 29/29 |
| one global non-diagonal residual really executes coupling | 18/18 |
| empty or incomplete structure is only a recoverable gap | 11/11 |
| ownership, pair, channel, and unit adversaries fail closed | 11/11 |
| missing, ambiguous, and foreign provider are recoverable | 12/12 |
| content-addressed cache and deterministic fresh replay | 10/10 |
| numerical failure and caught unknown remain typed | 8/8 |
| sealed bodies and ForwardChainContext are revalidated | 10/10 |
| authority ceiling remains manufactured screen only | 8/8 |

Final current-source checks after the review corrections:

```text
julia --startup-file=no --history-file=no --project=. examples/runtime_v4_conservative_multiregion_execution.jl
CMR_FINAL_EXAMPLE_EXIT=0

julia --startup-file=no --history-file=no --project=. test/runtime_v4_core_tests.jl
RuntimeV4 contracts and exact capability closure: 20/20 pass
RuntimeV4 hash derivation, cache and fail-closed execution: 6/6 pass
CMR_FINAL_CORE_EXIT=0

julia --startup-file=no --history-file=no --project=. test/runtime_v4_spine_tests.jl
frozen StageSpec derives Cartesian gaps: 11/11 pass
admission and closure are separate: 11/11 pass
spine reports unresolved provider coverage: 6/6 pass
typed evidence binding closes exact Cartesian scope: 21/21 pass
prerequisite closure is typed and P5 stays withheld: 5/5 pass
CMR_FINAL_SPINE_EXIT=0
```

## Example result and interpretation

The two-region fixture assembles `((2.5, -0.5), (-0.5, 3.5))`, containing two
nonzero off-diagonal entries. From initial state `(1.0, -1.0)`, one global
linear correction reaches residual `(0.0, 0.0)`. The paired discrete interface
terms cancel exactly, so the structural interface defect is `0.0`.

The region diagonal and interface coefficient are manufactured lumped inputs;
they are not derived from a real multiphysics constitutive provider. Exact
pair cancellation therefore must not be presented as measured or continuum
physical conservation.

## Remaining blocking edges

- connect a declared real physical provider whose governing/source/boundary
  terms are derived from the same candidate and forward context;
- replace lumped regions with typed spatial discretizations and interface
  transfer appropriate to the declared physics;
- land engineering/control/fault obligations without caller-supplied evidence;
- land held-out physical validation and UQ; and
- run integrated whole-device closure before any physical feasibility or
  minimal-device claim.

Current authority remains `p5_ready=false`; credible physical-device count is
zero.
