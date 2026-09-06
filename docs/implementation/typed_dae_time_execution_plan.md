# D2.2 typed DAE time execution

## Accepted scope

D2.2 is a candidate-bound, zero-dimensional, constant-mass, local index-1
backward-Euler trajectory screen. It consumes the exact sealed plan and passing
report from D2.1. The first trajectory point must reproduce every
`StateValueV4(ref, value, unit)` from the D2.1 final state in the same order.

The real mixed-state fixture remains:

```text
xdot = -x
z1 + z2 - 3 = 0
z1 - z2 - 1 = 0
```

For each fixed step, D2.2 jointly solves the new-time unknowns using:

```text
Md * (x[n+1] - x[n]) / h - f(x[n+1]) = 0
g(z[n+1]) = 0
```

The external discrete oracle `x[n] = (1+h)^(-n)` is used only by tests. The
executor obtains `Md`, `f`, and `g` from the compiled operator hypergraph,
typed AST roots, row bindings, and operator manifests; it does not encode the
fixture equations or expected solution.

## Frozen authority

The D2.2 plan binds the D2.1 plan, report, and artifact hashes; compiled prefix;
all three Genome hashes; mission, bounds, and minimality scope; scenario and
both numerical protocols; complete row/operator/root/output/port authority;
physical subject; capability; provider manifest; solver input; and D2.2 source
hash. Validation rebuilds these identities and deterministically re-executes the
artifact. A foreign or non-passing initialization is rejected before any state
is read.

The protocol fixes backward Euler, the time span, exact time dimension, step,
step budget, time scale, Newton and line-search budgets, dimensionless residual
and correction tolerances, finite-difference step, relative SVD rank threshold,
and condition ceiling. The time span must contain an integer number of steps.

## Numerical gates

Typed bounds derive the state column scales and algebraic row scales. The
differential row scale is the differential-state scale divided by the sealed
time scale. Each step uses bounds-aware central or one-sided finite differences
and a deterministic relative-SVD rank test. A step is accepted only after
recomputing and passing:

- scaled backward-Euler differential residual;
- scaled algebraic residual;
- joint Newton Jacobian rank and condition;
- local scaled `Jzz` rank and condition;
- state bounds, units, ordering, and finite-value checks.

The full joint step Jacobian is recomputed unconditionally at the accepted
candidate, including when the initial Newton guess already has zero residual.
Its condition is sealed into every post-t0 point, the result summary, and
runtime evidence; a residual-zero but singular discrete operator is rejected.

Numerical failure retains the already accepted typed trajectory and the failed
step index. Unexpected exceptions remain `unknown`. Provider absence is
`terminal_deferred`, produces no artifact, and does not mutate the execute-once
store. Cache validation requires exactly one artifact authority for the solver
input; replay recomputes the complete result.

## Temporal and physical boundary

The frozen vocabulary still has no declared temporal cast between differential
and algebraic states. D2.2 therefore preserves the D2.1 restriction: the RHS
reads only the differential partition and algebraic constraints read only the
algebraic partition. The code executes a real mixed/index-1 numerical path, but
does not claim cross-temporal physical coupling.

D2.2 always reports `screen_only`, zero credible physical candidates,
`p5_ready=false`, and `unsupported_emitted=false`. It is not an adaptive or
event-aware integrator, time-step convergence study, spatial/Gridap solve,
G2/G3 execution, engineering/control scenario, whole-device assembly, VVUQ,
validation result, feasibility proof, or promotion authority.

## Stop condition

The milestone stops when the graph-derived nontrivial trajectory matches the
backward-Euler oracle, t0 equals the sealed D2.1 artifact, all per-step gates and
sealed evidence/cache/replay controls pass, the six-file allowlist is respected,
and D1/D2.1 regressions remain green. New temporal casts, cross-partition
coupling, events, refinement, spatial execution, and higher evidence levels are
separate later milestones.
