# RuntimeV4 typed 3-D physical-provider input

## Decision

This slice introduces a candidate-bound declaration and gap compiler for the
input of a future three-dimensional physical provider. It deliberately stops
before provider selection or execution.

The declaration contains typed Fourier boundary coefficients, a three-
dimensional coordinate map and metric, radial pressure plus iota/current
profiles, and toroidal flux. The coordinate and metric AST-root identities are
dereferenced against the current compiled G2 operator hypergraph. The resulting
subject binding seals the exact G2 Genome, graph, graph binding, all AST-root
identities, mission, bounds, and selected scenario.

## Current status semantics

The only implemented resolution is `recoverable_gap`. On the existing generic
G2 fixture it names eight absent edges. A manufactured compiler fixture closes
only typed geometry/profile ownership and leaves four exact gaps:

- region constitutive, source, and boundary laws;
- oriented interfaces and discrete spaces;
- governing residual and Jacobian ownership;
- discretization controls.

`input_complete` is reserved for a later integration that closes and validates
all four edges. The present declaration is a compiler fixture, not a solver
input accepted by DESC, VMEC, or another production provider.

## Authority boundary

This slice selects no provider, executes no solver, emits no evidence, grants
no physical or engineering validation credit, and has no promotion, P5,
closure, or terminal authority. Its claim ceiling is `screen_only`; credible
physical-device count remains zero.

## Legacy disposition

| Disposition | Material | Decision |
| --- | --- | --- |
| Extract | 3-D Fourier geometry and radial-profile intent | Re-express as typed immutable declarations owned by current G2. |
| Wrap | coordinate/metric programs | Bind their actual typed AST roots and graph identities. |
| Test-only | manufactured geometry/profile fixture | Proves compiler and binding behavior only. |
| Reject | family labels, candidate preferences, and legacy pass flags | They cannot route providers or establish evidence. |
| Defer | constitutive/interface/residual/discretization contracts | Preserve as explicit recoverable gaps. |
