# ForwardChainContextV4

## Scope

`ForwardChainContextV4` is the narrow common identity boundary requested by the
forward-contract integration review. It is an isolated RuntimeV4 source file;
it is not included or exported by `FusionRuntimeV4.jl` yet.

The context binds one actual `CandidateStatePackageV4`, its validated
`CompiledCandidatePrefixV4`, the exact `GenomeContractRegistryV4`, declared
mission and bounds payloads, comparison and scenario scopes, a materialized
`ExecutablePhysicalSubjectV4`, and one selected scenario. A batch factory
creates one context per frozen scenario only when the batch exactly matches the
subject order.

This boundary is identity and admission infrastructure only. It emits no
`RuntimeEvidenceV4`, stage result, promotion, physical validation credit, or
terminal classification. A `prefix_incomplete` candidate can have a valid
context while its unresolved nonterminals remain in the compiled prefix.

## Sealed types

Three private-token types form the boundary:

- `ForwardGraphBindingV4` binds one of `:mechanism`, `:field_geometry`,
  `:realization`, or `:control` to an actual `TypedOperatorHypergraphV1`;
- `ForwardGenomeBindingV4` binds exactly one of the three Genome contract roles
  to its contract reference, recomputed Genome hash, and owned graph bindings;
- `ForwardChainContextV4` binds the complete validated upstream identity.

Callers use `make_forward_chain_context` or `make_forward_chain_contexts`.
There is no public constructor that accepts hashes.

## Validation chain

Construction and every later `canonical_hash(context)` call rerun the checks.
The stored `context_hash` is never returned without reconstruction.

1. `_runtime_validate_compiled_prefix` is called with the actual candidate,
   registry, mission, bounds, comparison scope, and scenario scope.
2. Candidate identity includes `identity_ref` plus its full semantic body, so a
   new candidate name cannot alias a compiled candidate merely because their
   three Genome hashes are equal.
3. The three candidate contract refs must match the corresponding registry
   roles and must have three distinct canonical identities. Roles are fixed as
   `mechanism`, `field_geometry`, and `realization_control`; omission,
   duplication, or reordering is rejected.
4. Mechanism, field/geometry, realization, and control graph bindings are
   reconstructed from the compiled prefix. Graph ownership is fixed by Genome
   role.
5. Candidate Genome hashes and the mission-bound Genome bundle hash are
   recomputed from the actual Genome objects and checked against
   `candidate.canonical_hashes`.
6. Subject prefix, Genome bundle, mission, bounds, and subject-body hash are
   recomputed. The subject must have nonempty materialized bindings, a non-null
   immutable materialized payload, and frozen scenarios.
7. Subject scenario names must exactly equal the compiled scenario scope in
   order. Scenario canonical hashes must be unique. The selected scenario must
   have exactly one matching canonical identity in the subject.
8. Obligations are obtained only from
   `derive_capability_obligations(compiled)`. Their hashes must be unique and
   must exactly match `subject.operator_obligations` in compiler order.

## Strong graph identity

The existing canonical graph digest is retained but is not the only graph
identity. `ForwardGraphBindingV4` additionally derives:

- ordered node identity hashes containing position, `node_id`, kind, physical
  type, and label;
- ordered hyperedge identity hashes containing position, `edge_id`, typed port
  bindings, role, AST/program identity, conservation effects, interface flux
  pairs, and operator-registry identity where applicable;
- ordered AST-root identity hashes containing graph role, edge identity,
  program identity, root position and node, and the bound graph output node.

Node and edge IDs must be unique inside each graph. This closes the ownership
gap left by semantic graph hashes that intentionally omit labels or IDs.

## Canonical context body

The context digest is derived from a body that excludes `context_hash` and
contains only recomputed identities:

- revision;
- candidate and compiled-prefix hashes;
- registry, mission, and bounds hashes;
- normalized comparison and scenario scopes;
- physical-subject and selected-scenario hashes;
- the three sealed Genome-binding hashes;
- compiler-derived obligation hashes.

`validate_forward_chain_context` reconstructs all bindings and the complete
body from the held objects. Any mismatch is an `ArgumentError`; there is no
best-effort or degraded construction path.

## Usage

The runnable example is
`examples/runtime_v4_forward_chain_context.jl`. Its two-scenario fixture uses a
materialized immutable software payload and remains `prefix_incomplete`; it is
not physical evidence.

```julia
contexts = make_forward_chain_contexts(candidate, compiled, registry,
    mission_payload, bounds_payload, comparison_scope, scenario_scope,
    subject, subject.scenarios)

context = first(contexts)
validate_forward_chain_context(context)
mechanism = forward_graph_binding(context, :mechanism)
g3 = forward_genome_binding(context, :realization_control)
```

Future forward modules should accept the context object and typed graph
bindings directly. They must not copy these checks or accept substitute hashes.
