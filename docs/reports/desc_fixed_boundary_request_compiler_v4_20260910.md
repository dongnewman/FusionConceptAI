# DESC fixed-boundary request compiler V4 - 2026-09-10

## Decision

This slice now stops at an honest, candidate-bound DESC translation proposal.
It reconstructs and validates the Runtime V4 3-D composition, exact subject
joins, a proposed coordinate/Fourier convention, DESC-specific controls, and
latent payload semantics. Current typed geometry does not prove that its
physical chart has the declared DESC semantics.

The public compiler therefore has only `recoverable_gap` status and cannot emit
an execution request. It adds no provider, process runner, solver execution,
result schema, receipt, or evidence.

## Fixture outcomes

The existing two-region composition owns no DESC declarations or binding and
returns exactly:

```text
status=recoverable_gap
required_desc_geometry_convention_declaration
required_desc_fixed_boundary_request_declaration
required_desc_fixed_boundary_request_subject_binding
```

The separate manufactured candidate owns a proposed convention declaration,
DESC controls, all six composition-component bindings, the composition binding,
and the request-subject binding. Its domain values pass the bounded mapping
checks, but `geometric_compatibility_proved=false`. It returns exactly:

```text
status=recoverable_gap
required_verified_desc_geometric_compatibility_proof
request_emitted=false
```

No proof method or proof-artifact hash is accepted. Recomputing an arbitrary
hash cannot change either outcome.

## Integrity and canonical hardening

The request-binding factory receives and validates the composition binding and
all six component bindings. It reloads declarations from the compiled candidate
and reconstructs the composition binding against the exact candidate, prefix,
registry, mission, bounds, comparison scope, scenario scope, and scenario. Both
canonical hash and semantic view must match.

An absent request binding is a recoverable capability gap. Duplicate DESC
request bindings and orphan request bindings are integrity errors and throw.

All five local value types use a mutable private flyweight token whose identity,
not merely its type, is required by inner constructors. Canonical validators
recheck fixed semantics, ranges, hashes, and authority. Self-consistent forgeries
with recomputed hashes are rejected. The dormant request validator always
rejects because this revision has no verified geometry-proof contract.

## Generic versus DESC controls

The latent envelope retains the generic discretization input hash but states
`generic_control_translation=:none`. It does not silently map generic mesh,
finite-element, nonlinear, linear-solver, tolerance, preconditioner, restart,
or refinement controls to DESC fields. Such a mapping needs its own reviewed
typed contract.

## Authority ceiling

Convention, controls, binding, dormant request envelope, resolution, and
manifest preserve:

```text
model_class=manufactured_input_fixture
claim_ceiling=screen_only
geometric_compatibility_proved=false
provider_selected=false
provider_executed=false
solver_execution_attempted=false
solver_executed=false
physical_validation=false
engineering_validation=false
emits_evidence=false
grants_pass=false
promotion_authority=false
p5_ready=false
terminal_authority=false
credible_physical_device_count=0
```

## Verification

Focused tests cover exact closed-vocabulary gap ordering, all subject joins,
composition rebuilding, foreign binding rejection, duplicate/orphan integrity
failures including an incomplete upstream composition, latent payload
validation, control endpoints and adversaries, Fourier symmetry/orientation/
radius/mode gates, 21-point pressure/iota checks, private-token identity,
self-consistent forgeries, and complete authority metadata.

The focused command
`julia --project=. scripts/run_v4_desc_fixed_boundary_request_compiler.jl`
passed 223 of 223 assertions and printed
`DESC_FIXED_BOUNDARY_REQUEST_COMPILER_OK`.

No DESC interpreter or solver was started.

## Remaining work

The next admissible edge is a separately reviewed, candidate-bound, executable
geometry-proof contract for the Runtime chart-to-DESC coordinate, phase,
periodicity, and orientation mapping. Request emission cannot be reconsidered
before that proof exists. Provider process, result, receipt, replay, caching,
and capability-routing slices remain separate future work.
