# RuntimeV4 typed 3-D governing residual/Jacobian ownership

## Decision

This isolated compiler slice implements only the third remaining accepted
`ThreeDPhysicalProviderInputV4` gap:
`required_typed_three_d_governing_residual_jacobian_ownership`.

`declare_three_d_governing_residual_jacobian_set` receives an actual current-G2
`ForwardGraphBindingV4` plus an immutable tuple of state/residual/Jacobian edge
selectors. Selectors carry no authority. The declaration is an ordered exact
cover: every current G2 `:state` node has exactly one pair, in G2 node order,
even if selectors arrive in another order. Missing, duplicate, or extra state
selectors fail closed. All residual and Jacobian codomain nodes must also be
covered exactly, and state, edge, AST-root, and output-node identities cannot
be shared between pairs.

Each pair resolves two distinct `AtomicMIMOHyperedgeV1` edges. The residual
must have role `governing`, its own state as its sole domain, one `:residual`
codomain whose value kind is `governing_residual`, and a registered
`ASTApplyV1` root. The Jacobian must have role `constraint`, the same state as
its sole domain, one `:jacobian` codomain, and its own registered `ASTApplyV1`
root. Each operator identity seals edge position and identity, program and AST
root identity, operator reference and manifest hash, domain/codomain node
identity, physical type, and a recomputed identity hash.

## Per-state type compatibility

Every state, residual, and Jacobian type must use static three-dimensional
semantics. For each pair, the required Jacobian type is derived rather than
supplied:

- tensor rank = state rank + residual rank;
- spatial dimension = 3;
- temporal type = residual temporal type, equal to the state temporal type;
- unit = residual unit / state unit.

The Jacobian edge must produce exactly that derived type. Labels and caller
digests cannot substitute for domain/codomain identity, units, rank, dimension,
or time semantics. A coupled G2 state set is therefore explicit and
composable: it is never collapsed to an arbitrary single state.

## Candidate, subject, and context binding

`ThreeDGoverningResidualJacobianBindingV4` is materialized before the physical
subject and seals the declaration, candidate, compiled prefix, G2 Genome,
graph, graph binding, ordered pair hashes, ordered residual/Jacobian AST roots,
mission, bounds, and selected scenario. The complete ordered set is then stored
as one typed subject binding.

Compilation consumes one exact declaration set and one exact subject binding
from the same sealed `ForwardChainContextV4`. It reconstructs the declaration
against the context-owned G2 identity inventory, checks all upstream links, and
creates `ThreeDGoverningResidualJacobianOwnershipV4`. The ownership additionally
seals context, registry, and physical-subject hashes. Detached one-argument
validation returns `false`; context-bound validation is required.

The accepted generic G2 fixture has neither a declaration set nor typed binding,
so it returns `recoverable_gap` with both exact missing edges plus the remaining
discretization-controls gap. The manufactured positive fixture has two distinct
states and two distinct pairs; it resolves this slice to `compiled` while
preserving `required_typed_three_d_discretization_controls` downstream.

## Canonicalization boundary

Every public trust boundary performs one complete upstream validation. The
declaration factory validates its current G2 graph binding; the subject-binding
factory calls `_runtime_validate_compiled_prefix`; and both context-bound
compile and ownership validation call `validate_forward_chain_context`.
After that one validation, inner per-state derivation and reconstruction reuse
the sealed node, edge, root, graph, and graph-binding identities rather than
recursively validating the same upstream object again. Operator, pair,
declaration, binding, ownership, and resolution `canonical_hash` methods still
reconstruct their own canonical body and compare it with the stored digest.
Stored self-hashes are never accepted as proof of an object's own integrity.

## Legacy disposition

| Disposition | Material | Decision |
| --- | --- | --- |
| Extract | v68 state ownership, exactly-one governing row, residual dependency, Jacobian row/column, unit, and spatial-dimension checks | Preserve the structural invariants as typed per-state compiler checks. |
| Wrap | current G2 `PhysicalType`, registered typed AST, `AtomicMIMOHyperedgeV1`, and `ForwardGraphBindingV4` identities | Bind the actual immutable objects and their canonical identities as an ordered exact-cover set. |
| Test-only | old `residual_block!`/`jacobian_block!` interfaces and manufactured coupled-solve examples | Use only as design guidance for the manufactured compiler fixture; no callback is invoked and no solver result is imported. |
| Reject | mutable dictionary/vector manifests, caller-selected Jacobian modes/functions, legacy `pass`/`fail`/`unsupported`, solver envelopes, and evidence ceilings | They do not establish current-G2 ownership and cannot enter this slice as authority or evidence. |

## Authority boundary

`compiled` means only that the current candidate/context owns a structurally
compatible full-state residual/Jacobian set. The slice selects and executes no
provider, emits no evidence, grants no pass or promotion, and makes no P5 or
terminal decision. Its claim ceiling is `screen_only`; physical and engineering
validation remain false, and the credible physical-device count remains zero.
