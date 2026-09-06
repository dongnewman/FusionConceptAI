# D1.3 typed-time execution contract

D1.3 is a bounded authority and execution contract over the frozen D1.1–D1.2b
candidate-bound time path. It adds no physical model, no provider capability,
and no high-fidelity or VVUQ conclusion.

## Capability operations

The capability surface contains exactly three operations:

- `:continuous`: execute one candidate-bound continuous trajectory.
- `:three_level_refinement`: consume the existing D1.2a refinement receipt and
  preserve its step hierarchy and numerical disposition.
- `:single_threshold_event`: execute the D1.2b single threshold split,
  including pre-state, post-state, event log, and remainder trajectory.

Operation names are capability values, not device-family labels. Routing remains
by declared capability, input schema, provider, and evidence obligations.

## Standard RuntimeV4 authority

The contract reuses the existing `CapabilitySignatureV4`,
`ProviderManifestV4`, `ExecutablePhysicalSubjectV4`, `SolverInputV4`,
`RuntimeEvidenceV4`, and `StatusVectorV4`. The execution plan binds, by exact
digest, all three Genome layers, mission, bounds, compiled prefix, physical
subject, scenario, provider manifest, input schema, and provider code source.
The provider is static in this milestone: `executor = nothing`; no dynamic
executor is silently installed or inferred.

## Static execution and ownership

The only execution entry point is the typed overload
`execute_once!(store, input, provider, plan)`. The ownership store is keyed by
the solver-input digest. A hit must revalidate plan, subject, scenario,
provider, schema, trajectory, result, receipt, and evidence identities; a
foreign or self-consistently rehashed artifact is rejected. A cache hit returns
the owned report without another physical or numerical execution.

The sealed objects are an execution plan, trajectory/event log, execution
receipt, and residual report. Their constructors are private to the contract
module and their canonical identities are re-derived during validation.

Replay is event-aware and read-only: it verifies the existing result against
the bound plan and scenario, never writes the ownership store, and never adds
execution counts. Refinement is receipt-bound rather than recomputed from
untrusted labels.

## Status and claim firewall

`fail`, `unknown`, `deferred`, and numerical partial evidence remain explicit
status outcomes with the available trajectory/counter evidence retained.
Missing, ambiguous, out-of-domain, initial-event-band, and multi-event cases
remain structured deferred outcomes where required by D1.2b; they are not
converted to unsupported-free success.

Every D1.3 report is fixed to `screen_only`, `credible_count = 0`,
`p5_ready = false`, and `unsupported = false` for this bounded contract. These
fields are independently checked and cannot be raised by a report payload.
D1.3 therefore makes no claim of high-fidelity assembly, whole-device closure,
manufactured control, or VVUQ.

## Frozen boundary

D1.1, D1.2a, and D1.2b source, fixtures, tests, numerical policy, and event
semantics are frozen inputs. D1.3 must not modify them or
`FusionRuntimeV4.jl`. Multiple-event ordering, mutable-matrix hardening,
high-fidelity device assembly, and VVUQ are later, separately reviewed work.
