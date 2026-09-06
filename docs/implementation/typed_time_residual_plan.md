# Candidate-bound typed time residual plan

## Scope and evidence boundary

Batch D1 adds a real, candidate-bound integration path for autonomous,
multi-state ordinary differential equations already expressed by the G1 typed
operator graph. It compiles the coefficient of every `DT@v1` occurrence from
typed mass roots, derives one constant mass matrix, evaluates separately typed
right-hand-side roots, and advances the resulting system with fixed-step RK4.

This batch does not add a user-authored mass matrix beside the AST. The AST is
the only governing-law authority. It also does not modify G1, G2, or G3 Genome
types or their published documents. `StructuredGridProtocolV4` and
`FieldResidualPlanV4` are RuntimeV4 types and are unrelated to the G3 Genome.
G3 realization and control graphs can already carry differential, discrete,
and event-typed nodes, so they must not be described as a static-field Genome.

D1 is deliberately bounded to autonomous ODEs with a finite, constant,
invertible mass matrix. Algebraic rows, a singular mass matrix, consistent
initialization, index analysis, and an index-1 DAE solver belong to D2. Spatial
operators and coupling to the Gridap field adapter belong to a later batch.

Every result remains `screen_only`. A manufactured integration pass is a
software and numerical control. It provides no validated physical model,
engineering closure, integrated device result, VVUQ completion, P5 readiness,
or credible physical candidate.

Implement in this order:

1. compile and integrate one real two-state, non-diagonal constant-mass ODE;
2. measure real step-refinement error and conservation drift;
3. execute a threshold event inside a step, split the step, apply the typed
   reset expression, and integrate the remainder;
4. add candidate, provider, receipt, replay, and adversarial bindings.

Do not begin with archive, authority, promotion, or whole-device wrappers.

## Additive files

Keep all tracked files in the D worktree byte-identical. Add only:

```text
src/RuntimeV4/TypedTimeResidual.jl
examples/runtime_v4_typed_time_fixture.jl
scripts/run_v4_typed_time_residual.jl
test/runtime_v4_typed_time_residual_tests.jl
docs/implementation/typed_time_residual_plan.md
```

The runner loads the repository package, includes the existing
`RuntimeV4/FusionRuntimeV4.jl`, and then uses `Base.include` to load the new
file into that module. Do not edit the package entrypoint, the RuntimeV4 module
file, Project/Manifest, Batch A sources, Batch B sources, or Genome files in
D1. `LinearAlgebra` is already a declared project dependency.

## What the frozen contracts do and do not provide

The existing G1 types provide the pieces needed to describe a bounded dynamic
subject:

- `PhysicalType` and `TemporalTypeV1(differential_time, order)` distinguish a
  state from its time derivative and carry units;
- `DT@v1` raises derivative order and subtracts one time unit;
- multi-root `TypedASTProgramV1` and `AtomicMIMOHyperedgeV1` bind ordered typed
  inputs and outputs to a governing edge;
- `MechanismGenomePayloadV1` requires exactly one governing edge for each
  differential or algebraic state;
- `ParameterGeneV1` provides a candidate-derived, bounded parameter value;
- the `THRESHOLD_SWITCH@v1` manifest provides typed control-signal, reset, and
  affected-state operands. Its frozen default manifest is event-marked but its
  allowed roles do not include the `event` hyperedge role, so D1 uses an
  additive carrier edge and binds its event semantics explicitly at runtime.

Those declarations do not provide a time interval, initial values, numerical
step, event threshold/direction/tolerance, event priority, or terminal policy.
State bounds are not initial conditions. Continuous `differential_time`
intentionally has no `clock_ref`, so D1 must not invent a Genome clock or
pretend that a discrete/event clock is the continuous integration axis.

Add the missing information as candidate-bound RuntimeV4 execution records:

```julia
TimeIntegrationScenarioV4(
    name,
    t_start,
    t_stop,
    time_unit,
    initial_values::Tuple{Vararg{StateValueV4}},
    event_bindings::Tuple{Vararg{TimeEventBindingV4}} = (),
)

TimeIntegrationProtocolV4(
    method = :fixed_rk4,
    step,
    max_steps;
    residual_abs_tol = 1e-10,
    residual_rel_tol = 1e-10,
    event_time_tol = 1e-10,
    event_value_tol = 1e-10,
    event_max_bisections = 80,
)

TimeResidualRowBindingV4(
    state_ref,
    governing_edge_hash,
    mass_root_position,
    rhs_edge_hash,
    rhs_root_position,
)
```

`time_unit` must be the time dimension. Times and step are finite, `t_stop` is
strictly greater than `t_start`, step is positive, and `max_steps` covers the
declared interval without an implicit extension. Initial values are sorted by
state ref, exactly cover all admitted differential states once, match their
units, lie within their declared bounds, and bind into the scenario hash.

## Publicly constructible G1 shape and mass derivation

D1 accepts scalar, lumped differential states with derivative order zero and
no spatial operator. The frozen type system intentionally distinguishes
`DT(y)`, whose temporal derivative order is one, from `rate*y`, whose temporal
derivative order remains zero even when its units are state-units per time.
Those values cannot be combined by `ADD@v1` into one typed AST root. D1 must
not add a cast or weaken that rule.

Use two existing public edge shapes for each admitted row:

1. exactly one governing edge owns the state. Its first root is an explicit
   `IDENTITY@v1` of the owned state, bound back to that state node, and its
   second root is made only from constant-scaled `DT` terms and bound to a
   distinct derivative-order-one non-state node;
2. one additive RHS edge has a derivative-free root bound to a distinct
   derivative-order-zero non-state node with the same value kind, tensor rank,
   spatial dimension, and units as the mass root.

`TimeResidualRowBindingV4` explicitly pairs the governing mass-root position
and additive RHS edge/root with the owned state. The compiler rederives both
edges from the candidate and verifies the state pass-through root. This
RuntimeV4 binding supplies no coefficient or equation value; it declares which
already-typed roots form one row. Its fixed semantics is

```text
mass_root[i] = rhs_root[i]
sum_j M[i,j] * DT(y[j]) = f[i](y, p)
M * ydot = f(y, p)
```

Rows and columns are ordered by `StateGeneRefV1.value`, never by graph-node or
caller order. Every edge, program, root, input binding, output binding,
operator manifest triple, state type, residual type, parameter, row binding,
and candidate hash is rederived through public contracts.

Compile each mass root recursively to a constant `DT`-coefficient vector, and
compile each RHS root to a derivative-free evaluator. The accepted operator set
is the literal audited `v1` manifests for `IDENTITY`, `ADD`, `SUB`, `NEG`,
`SCALAR_MUL`, `SCALAR_DIV`, and, only in mass roots, `DT`.

- `DT` may act only directly on an admitted differential-state input.
- A product containing `DT` requires the other operand to be a finite,
  state-independent scalar constant.
- A divisor must be a finite, nonzero, state-independent scalar constant.
- Nested or second-order `DT`, a derivative of a parameter/expression,
  state-dependent mass, and nonlinear products involving `DT` are deferred.
- An RHS root may use nonlinear scalar multiplication and division allowed by
  the same typed manifests, but it may contain no `DT`.
- `ASTParameterV1` must bind uniquely by name and physical type to a frozen G1
  `ParameterGeneV1`; evaluate it with the public candidate-derived parameter
  transform. Missing, duplicate, or mismatched parameters are deferred.
- Registry type validation supplies unit closure. The compiled form also
  records each mass coefficient's row/column refs and coefficient type so that
  the numerical matrix is not detached from its physical units.

Every individual program must remain inside the existing G1 program and
canonicalization bounds. D1 neither raises those bounds nor combines the mass
and RHS programs into a larger hidden AST.

`TypedTimeResidualFormV4` is sealed and records the ordered states, row
bindings, governing/mass/RHS edge, program, and root hashes, typed mass
coefficients, numerical mass matrix, RHS evaluator revision, parameter hashes,
and form hash.
Compilation rejects a non-square, rank-deficient, nonfinite, or ill-conditioned
matrix before an executable is made. D1 uses a deterministic LU factorization
of this derived matrix; it never substitutes an identity matrix.

## Numerical kernel

For a compiled form, define

```text
ydot = M \ f(y)
```

and implement classical fixed-step RK4. Factor `M` once per execution. Use
`h = min(protocol.step, t_stop - t)` for the final partial step. Record every
accepted time and ordered state vector, the number of RHS evaluations, mass
matrix and trajectory hashes, finite-value diagnostics, state-bound exits,
conservation metrics requested by the fixture, runtime, and termination.

Recompute and record a trajectory residual diagnostic from the typed equation.
The diagnostic formula and norm are part of the protocol revision; it is not a
substitute for the manufactured final-state error or the step-refinement
study. A nonfinite RHS/state, failed factorization, exhausted step budget,
state-bound exit, or residual failure produces a replayable
`:numerical_failure` result and a `numerical_fail` report. It cannot throw away
the failed artifact and cannot enter a passing convergence study.

The primary manufactured fixture uses two states and a non-diagonal matrix.
It stays within the existing public type and small-program boundaries:

- each governing program has two state inputs, an explicit identity state
  root, and an eight-node mass root `2*DT(y1)+DT(y2)` or
  `DT(y1)+2*DT(y2)`;
- each additive RHS program has two state inputs and a five-node root
  `rate*(y2-y1)` or `rate*(y1-y2)`;
- `rate` is a typed inverse-time constant, the mass roots have derivative
  order one, and the RHS roots keep derivative order zero while matching the
  mass-root units.

The paired roots represent

```text
2*y1' + y2' = rate*(y2-y1)
y1' + 2*y2' = rate*(y1-y2)
```

with typed inverse-time coefficients. Its sum is constant and its difference
has a closed exponential solution. The exact solution is a test oracle only;
the production compiler and integrator must not contain its formula, state
names, edge names, or coefficients.

Run `t=0` to `t=1/rate` with steps `0.2/rate`, `0.1/rate`, and `0.05/rate`.
Record final-state error, observed RK4 order, invariant drift, runtime, and RHS
evaluations. Before running, register these acceptance limits from classical
RK4 theory for this smooth linear control: both successive maximum-norm errors
must strictly decrease, both observed orders must lie in `[3.5, 4.5]`, all
states must be finite, and normalized sum-invariant drift must be at most
`1e-12`. A result outside these limits is diagnosed; the limits are not
retrofitted to the observation. Do not replace this with a self-reported status
or a comparison against the old single-energy adapter.

## Event semantics for D1

`TimeEventBindingV4` binds one reviewed event-carrier edge hash to:

```text
threshold value and unit
crossing direction = rising | falling | either
priority
terminal flag
event-time and event-value tolerances from the protocol
```

D1 accepts only an additive carrier edge whose root uses the literal reviewed
`THRESHOLD_SWITCH@v1` manifest and therefore has `event=true`. This is necessary
because that frozen manifest cannot be the root of an `event`-role edge. The
runtime binding, edge hash, event-marked manifest hash, and this carrier rule
are all explicit in the plan hash; a role label is never guessed or rewritten.
The first operand is the typed scalar `control_signal` used as the guard; an
ordinary `scalar_field` cannot be cast or renamed into that type. The event
occurs when the guard value minus the bound threshold crosses zero in the
declared direction. The second operand is the typed reset expression. The
event output binding selects the affected differential state, and the reset
expression must match that state's exact physical type. This defines the D1
runtime semantics; the operator's type rule alone does not claim numerical
event semantics.

The additive event carrier is compiled by an independent D1.2b entry point.
Its guard input must be a declared differential `control_signal` state;
the runtime never casts or renames either kind. The carrier is a single-root
literal `THRESHOLD_SWITCH@v1`; reset is a separate, exact-target typed AST.
`EVENT_RESET`, parameterized or stateful resets, nested events, stochastic
operators, and unresolved simultaneous/conflicting event groups remain
deferred. Event-aware replay validates each continuous segment and the reset
remainder independently and never reuses a continuous-only replay across a
jump.

Detect a crossing over an RK4 step, locate it by deterministic bisection using
RK4 substeps until both event tolerances or the iteration limit is reached,
advance exactly to the event, evaluate and apply the typed reset, and integrate
the unused portion of the original step. If two events occur in the same
step, choose the earliest located time; use declared priority only for times
equal within tolerance. Record pre-state, post-state, edge hash, event time,
guard value, direction, priority, terminal flag, iteration count, and event
record hash. Prevent an immediate zero-time retrigger of the same crossing.

An event-marked carrier without exactly one matching runtime binding is
deferred. A binding for a root whose manifest is not event-marked, a wrong
threshold unit, missing/ambiguous reset,
unsupported `EVENT_RESET`, contradictory direction, tied priority, or failed
root localization is also deferred or numerical failure as appropriate. No
threshold, reset value, direction, or terminal behavior may be defaulted.

## Provider and artifact bindings

After the numerical and event milestones pass, add sealed:

- `TypedTimeResidualPlanV4`;
- `TimeIntegrationReceiptV4`;
- `TimeIntegrationResultV4` and `TimeEventRecordV4`;
- `TypedTimeResidualReportV4`.

The plan binds candidate and separate G1/G2/G3 hashes, compiled prefix,
mission, bounds, governing graph, ordered state refs/types/bounds, form,
scenario, protocol, event edges/bindings, Julia/backend identity, adapter source
hash, status, gaps, and plan hash. Binding the G3 hash does not mean D1 executes
the G3 realization or control graphs.

Use a family-neutral capability and provider identity:

```text
kind               = typed_constant_mass_ode_integration
backend            = julia-fixed-rk4-dense-lu
independence_group = julia-typed-time-residual-v1
claim_ceiling      = screen_only
```

The provider executor rechecks input-schema, physical-subject, scenario,
requested-obligation, plan, source, and provider hashes. The public execute
path rejects a foreign manifest or executor, uses `execute_once!`, retrieves
only the artifact created by that invocation, verifies receipt/result hashes,
and returns `:evaluated_screen` only when numerical status and RuntimeEvidence
status are both passing. Public construction of sealed plan, receipt, result,
event record, and report types must fail.

## Acceptance matrix

| Boundary | Positive control | Mandatory negative control |
|---|---|---|
| typed subject | two differential states, governing pass-through/mass roots plus paired additive RHS roots, literal manifests | missing/duplicate row binding, wrong role/root/output, foreign candidate/prefix/graph |
| mass derivation | real non-diagonal constant invertible matrix derived from `DT` terms | identity substitution, singular/non-square matrix, non-affine or state-dependent `DT`, nested `DT` |
| state/RHS | nonlinear derivative-free typed evaluator, candidate-derived parameters | missing parameter, wrong unit/type, unsupported operator, hidden default |
| initial/time | reversed IC input order canonicalizes identically; exact typed coverage and finite tspan | missing/duplicate/foreign IC, wrong unit, out of bounds, invalid tspan/step/budget |
| integration | three real RK4 runs, finite trajectories, decreasing final error, observed order near four | one time step only, nonfinite RHS/state, bound exit, fabricated convergence status |
| event | guard crosses inside a step, deterministic root time, typed reset, remainder integrated | endpoint-only event, no step split, wrong direction/unit/reset, missing/foreign event binding |
| replay | identical input gives identical plan, trajectory, event, receipt, result, and report hashes | mixed scenario/protocol/result, foreign provider/executor, altered source hash |
| DAE boundary | none in D1 | algebraic state, zero mass row, singular mass, or consistent-initialization request is explicitly deferred to D2 |
| authority | report and evidence stay `screen_only`; credible count and P5 remain unchanged | candidate-bound/validation ceiling, physical promotion, whole-device or VVUQ claim |

## Milestones and stop rules

### D1.1: real multi-state integration

Construct the fixture only through the frozen public G1 constructors. Compile
the paired two-state roots, print the derived non-diagonal mass
matrix, integrate one trajectory, and compare against the external analytic
oracle. Verify finite states, nontrivial state evolution, conservation drift,
and a recomputed residual diagnostic. If this fails, diagnose AST extraction,
units, mass ordering, or RK4. Do not add provider wrappers first.

### D1.2: refinement and event split

Run three halved steps and record real errors and observed orders. Then run a
case whose threshold lies strictly inside a nominal step; show the located
event time, pre/post states, reset, and final remainder state. Include a
wrong-direction or no-split control that distinguishes the accepted result.

### D1.2b scope boundary

D1.2b executes one candidate-bound threshold split. Multiple same-step event
brackets remain structured deferred artifacts; earliest-event selection and
priority resolution are D1.2c obligations. The current numerical kernel uses
a mutable matrix internally; immutable matrix storage and its sealed identity
checker are subsequent hardening work. Every result is `screen_only` and is
not a high-fidelity, whole-device, or VVUQ claim.

### D1.3: binding and adversarial controls

Seal and bind the plan, provider, subject, input, evidence, receipt, trajectory,
event log, result, and report. Complete all negatives in the acceptance matrix
and verify every pre-existing tracked file is byte-identical.

D1 ends only after D1.1-D1.3 pass with zero credible physical candidates and
`p5_ready=false`. D2 may then add a separately reviewed index-1 constant-mass
DAE path with consistent initialization and algebraic residual checks. Spatial
time coupling starts only after the independent Gridap and time adapters are
both stable.
