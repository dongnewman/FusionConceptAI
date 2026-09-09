# RuntimeV4 typed oriented 3-D interface input

## Decision

This isolated slice makes multi-region interface topology and discrete spaces
explicit, typed, and candidate-bound. It compiles only declarations stored in
the current G2 field Genome and validates them against the exact
`ForwardChainContextV4`.

Each region declares one three-dimensional volume space and owns one current
G2 state node. Each oriented interface declares minus/plus endpoint regions,
two trace spaces, one multiplier space, and a conservation-ledger identity.
The minus trace support must be the minus region support, the plus trace
support must be the plus region support, and the multiplier may use a separate
interface or mortar support. Every referenced support must resolve uniquely in
the current G2 fields.
Callers do not declare interface coefficients. The compiler obtains the
endpoint identities, orientation, and exact rational coefficients from the
matching `InterfaceFluxPairV1` on an actual `AtomicMIMOHyperedgeV1`.

The compiled references seal:

- the region support and state-node identity hashes;
- the interface hyperedge, operator-program, and AST-root identity hashes;
- the exact ledger pair position and hash;
- the separate interface/mortar support identity hash;
- the minus and plus region-reference and state-node hashes;
- the G2 Genome, graph, graph binding, mission, bounds, and scenario hashes.

Declarations must exactly cover all current G2 state nodes and every interface
flux pair. The region/interface topology must be connected. Spaces use typed
roles and exact owners, supports, basis families, physical types, polynomial
orders, and quadrature orders.

## Current status semantics

The generic current 3-D context has no oriented-interface declaration or
subject binding, so resolution returns `recoverable_gap` with exactly:

- `required_typed_three_d_oriented_interface_discrete_spaces`;
- `required_three_d_oriented_interface_subject_binding`.

A two-region manufactured compiler fixture supplies distinct left-region,
right-region, and interface/mortar supports plus both required input edges, and
resolves to `input_complete`. This status means only that the typed interface
input is complete for this compiler slice. It is not provider readiness,
solver execution, validation evidence, or a device claim.

## Authority boundary

The declaration, binding, input, resolution, and manifest select no provider,
execute no solver, and emit no evidence. They grant no physical or engineering
validation, promotion, P5, or terminal authority. The claim ceiling remains
`screen_only`, and credible physical-device count remains zero.

## Legacy disposition

| Disposition | Material | Decision |
| --- | --- | --- |
| Extract | `universal_multiregion_topology_grammar_v89.jl` topology and paired-sign intent plus `multiregion_equilibrium_ir_v93.jl` multiplier-space intent | Re-express as immutable typed declarations owned by current G2 fields. |
| Wrap | current typed MIMO interface ledger, replacing the old dictionary pairs | Bind its actual edge, program, AST-root, endpoint, pair, and coefficient identities. |
| Test-only | manufactured two-region interface | Proves deterministic compilation and fail-closed binding only. |
| Reject | old `Dict{String,Any}` payloads, caller-supplied coefficients, wildcard ownership, family preference, and pass flags | None may substitute for current typed G2 identity. |
| Defer | constitutive/residual assembly, numerical provider, solver execution, and evidence | Preserve outside this input-only compiler slice. |
