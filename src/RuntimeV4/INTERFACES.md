# RuntimeV4 core interface

The runtime module is additive and is loaded after `using FusionConceptAI`.
It consumes a complete `CandidateStatePackageV4`; it does not recreate or
reinterpret any of the three Genome contracts.  Labels, identity strings,
family names, proposal lineage, archive memberships, lifecycle and search
metadata are excluded from routing and physical hashes.

```julia
compile_candidate(candidate, registry, mission, bounds)
compile_candidate(candidate, registry; mission_payload=mission, bounds_payload=bounds)
derive_capability_obligations(compiled)
match_provider(obligation, manifests)
materialize(compiled, bindings, scenarios)
compile_solver_input(subject, scenario, provider)
compile_solver_input(subject, scenario, obligation, provider)
execute_once!(store, input, provider)
```

`compile_candidate` reads `candidate.mechanism_genome_ref.payload.operator_graph`,
`candidate.field_geometry_genome_ref.graph`, and the two G3 graphs.  A typed
operator graph yields the fixed structural screen obligation; an unavailable
physical axis becomes an entry in `unresolved_nonterminals` and prevents
materialization.  There is no family or default component template.

P1 emits only the fixed `:structural_screen` / `typed_structure_audit`
obligation.  Generic physical operator edges whose solver ABI, coordinates,
boundary closure, or component/control mapping are not declared remain
`unresolved_nonterminals`; they are never promoted to screen evidence.

`CapabilitySignatureV4` contains schema, revision, symbolic capability kind,
operator, complete state/source/target/coordinate/boundary/interface/time/
output axes, an applicability bounds hash, an input schema hash, and the
required evidence level.  Zero-dimensional lumped signatures may have an
empty coordinate tuple only with an explicit non-wildcard `coordinate_system`.

`ProviderManifestV4` must exactly repeat capability kind and input schema
hash.  `match_provider` compares every signature axis and the applicability
bounds; empty axes and wildcard values never match.  Provider backend
revision and code hash are bound into solver inputs and evidence, but are not
candidate routing axes.

`materialize` derives `physical_subject_hash` from the complete compiled
Genome content, mission/bounds, bindings and all declared scenarios.  The
`ExecutablePhysicalSubjectV4` constructor does not accept a caller-supplied
hash.  `compile_solver_input` similarly derives `solver_input_hash` from the
subject, one exact obligation, scenario, provider manifest, input schema and
materialized payload.  The three-argument form is only a convenience when
exactly one obligation matches; multi-obligation subjects must use the
four-argument form.

`execute_once!` caches by solver input hash and returns the original immutable
evidence on a cache hit.  A provider exception is `unknown` pending a solver
protocol classification; a provider without an executor is `unknown`; a
missing provider is `terminal_deferred`.
Runtime evidence and provider ceilings are limited to `none|screen_only`.
No runtime core API emits terminal `credible_within_scope` or `unsupported`.
