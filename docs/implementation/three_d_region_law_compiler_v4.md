# RuntimeV4 typed 3-D region-law compiler

## Decision

This isolated slice implements only the first remaining accepted
`ThreeDPhysicalProviderInputV4` gap:
`required_typed_three_d_region_constitutive_source_boundary`.

`declare_three_d_region_laws` accepts a real G2 `ForwardGraphBindingV4` and
derives one region node plus constitutive, source, and boundary law roots from
objects already present in that graph. It records the canonical graph and graph-
binding hashes, typed node identities, `AtomicMIMOHyperedgeV1` identities,
program hashes, registered AST-root identities, roles, and physical types.
Labels are not used for inference, and no operator site is synthesized by the
compiler.

## Compilation semantics

`compile_three_d_region_laws` first revalidates the complete
`ForwardChainContextV4`. It then requires exactly one declaration in the
current G2 fields and reconstructs that declaration from the context-owned G2
graph. Before the context exists, `make_three_d_region_law_binding` seals the
declaration, G2 Genome, G2 graph and graph binding, all three law-root
identities, mission, bounds, and selected scenario. Compilation requires
exactly one such `ThreeDRegionLawBindingV4` in the physical subject and rebuilds
it from the current context. A missing declaration or subject binding returns
`recoverable_gap`; an ambiguous or foreign binding fails closed. Only a
declaration and binding that both reconstruct exactly return `compiled`.

`compiled` means only that this one typed declaration is structurally owned by
the current candidate and scenario context. The result continues to expose the
three downstream input gaps for oriented interfaces and spaces,
residual/Jacobian ownership, and discretization controls. It is not an
`input_complete` result.

## Manufactured fixture boundary

The sole positive fixture contains registered AST operator applications on
three distinct `AtomicMIMOHyperedgeV1` edges with typed `governing`, `source`,
and `boundary` roles. Its region, source, and boundary nodes are static
three-dimensional physical types. The source edge carries an explicit typed
net-creation conservation account. This is a compiler fixture only; no
numerical law is evaluated.

## Authority boundary

The slice selects and executes no provider, emits no evidence, grants no pass
or promotion, makes no P5 or terminal decision, and performs no physical or
engineering validation. Its claim ceiling is `screen_only`, and the credible
physical-device count remains zero.

## Legacy disposition

| Disposition | Material | Decision |
| --- | --- | --- |
| Extract | `multiregion_equilibrium_ir_v93.jl` region/equation/source/boundary separation | Preserve the requirement that every region owns explicit laws. |
| Wrap | `multiregion_residual_compiler_v89.jl` governing/additive/boundary assembly intent | Rebind it to current typed nodes, registered AST operators, hyperedges, and roots. |
| Test-only | old reduced control-volume solve and the new manufactured three-law graph | Use only to exercise compilation and identity checks. |
| Reject | legacy `Vector{Dict{String,Any}}`, candidate-family routing, numerical pass flags, and claim authority | None enters the RuntimeV4 contract or evidence path. |
| Defer | provider numerical kernels and physical constitutive calibration | Keep outside this compiler-only milestone. |
