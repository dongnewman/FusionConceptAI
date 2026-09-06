# D2.1 typed DAE consistent initialization

## Accepted scope

D2.1 is a candidate-bound, zero-dimensional, local index-1 numerical screen at
the initial time only. It consumes a compiled three-genome prefix, typed state
references, explicit residual-row bindings, a typed initial-value scenario, and
a sealed numerical protocol. The fixture deliberately contains one
differential state and two coupled algebraic states:

```text
xdot = -x
z1 + z2 - 3 = 0
z1 - z2 - 1 = 0
```

Starting from `(x, z1, z2) = (1, 0, 0)`, bounded Newton may correct only the
algebraic values. The accepted result is `(1, 2, 1)` with `xdot = -1`; the
differential value must remain exactly unchanged.

## Typed authority and physical boundary

The state partition comes from each `StateGeneV1` temporal type, not from a
device or topology label. Every differential and algebraic row is bound to real
operator-hypergraph edges and typed AST roots. Compilation verifies state and
output ownership, governing/constraint roles, the operator allowlist, complete
operator-manifest bindings, scenario units and bounds, all three genome hashes,
the compiled prefix, mission, bounds, minimality scope, and source identity.

The currently frozen operator vocabulary has no declared projection between
`differential_time` and `algebraic_time`. D2.1 therefore demonstrates a real
mixed-state candidate and a coupled algebraic block, but it does not invent a
cross-temporal coupling operator. This restriction is explicit evidence scope,
not a device-family special case.

## Numerical gates

Execution derives deterministic row and column scales from each typed state's
finite declared bounds, expressed in that state's declared base unit. The
protocol also seals a positive time scale and requires the exact time-dimension
unit; differential derivative and mass-residual scales are state scale divided
by this time scale. Residuals,
corrections, the algebraic Jacobian, the mass residual, and matrix condition
audits are evaluated in this sealed dimensionless coordinate system. It then
forms the constant differential mass block `Md`, solves only the algebraic
block with bounded finite-difference Newton, and recomputes:

- the final algebraic residual `g(z)`;
- the local algebraic Jacobian `Jzz` and its rank/condition;
- the initial differential derivative;
- the differential mass residual `Md*xdot - f`;
- the algebraic correction norm and differential-state immutability.

Finite differences use central samples when both directions are in bounds and
one-sided samples at a bound; a state with no usable perturbation fails. Matrix
rank uses a protocol-sealed relative SVD threshold rather than a platform
default. Iteration, residual, mass-residual, correction, finite-difference,
rank, condition, and line-search limits are sealed into the protocol and plan
hashes. Nonfinite, singular, ill-conditioned, out-of-bounds, stagnating, or
nonconvergent cases are terminal `numerical_fail` artifacts. Unexpected backend
exceptions remain `unknown`. A missing provider remains deferred and creates no
execution artifact or store mutation.

## Sealed evidence chain

Capability, physical subject, provider, solver input, authority, plan, result,
runtime evidence, receipt, and report identities are recomputed during
validation. Execute-once storage is keyed by the solver-input identity; replay
must reproduce both the artifact and the complete report. Adversarial tests
cover substitutions and tampering across this chain.

## Claim firewall and stop condition

D2.1 always reports `screen_only`, zero credible physical candidates,
`p5_ready = false`, `unsupported_emitted = false`, and no trajectory. It is not
a time integrator, spatial/Gridap solve, G2/G3 executor, coupled-DAE
demonstration, high-fidelity assembly result, VVUQ result, feasibility proof,
promotion decision, or evidence of a new physical device.

The milestone is complete when the real mixed fixture, negative gates,
execute-once/replay behavior, sealed evidence chain, runner, and prior RuntimeV4
regressions pass. Further DAE capability belongs to a later milestone; D2.1 is
not expanded after this acceptance boundary.
