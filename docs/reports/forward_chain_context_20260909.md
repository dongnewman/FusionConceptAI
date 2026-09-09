# ForwardChainContextV4 focused implementation report — 2026-09-09

## Outcome

Implemented the integration review's first exit gate as new isolated files.
The slice establishes one fail-closed forward identity for the actual three
Genome objects, four compiled typed graphs, compiler-derived obligations,
mission/bounds/scopes, materialized physical subject, and frozen scenarios.

No aggregator or previously rejected forward module was edited. The new source
is not exported or integrated. No commit or push was made.

## Files

- `src/RuntimeV4/ForwardChainContext.jl` — sealed context and binding types,
  factories, identity derivation, accessors, and validators;
- `test/runtime_v4_forward_chain_context_tests.jl` — positive and adversarial
  focused tests;
- `examples/runtime_v4_forward_chain_context.jl` — runnable two-scenario
  materialized software fixture;
- `docs/implementation/forward_chain_context.md` — contract and invariants;
- `docs/reports/forward_chain_context_20260909.md` — this verification record.

## Verified behavior

The focused suite covers:

- exact positive candidate/prefix/registry/subject/scenario binding;
- all three distinct Genome roles and all four owned graph roles;
- recomputed G1/G2/G3 and bundle hashes;
- node ID, edge ID, typed port, program, AST-root, and output-node identity;
- compiler-derived obligation equality with subject obligations;
- foreign candidate identity and registry rejection;
- duplicate Genome contract-role rejection;
- swapped graph-owner rejection;
- mission, bounds, comparison-scope, and scenario-scope drift;
- prefix, bundle, mission, bounds, materialization, binding, and obligation drift
  in the physical subject;
- absent, foreign, reordered, missing, and duplicate/ambiguous scenarios;
- private constructor boundaries;
- tampered graph, Genome, candidate, registry, scenario, obligation, and context
  hashes;
- explicit absence of evidence and terminal-authority output fields.

## Commands and results

Focused test:

```text
julia --project=. test/runtime_v4_forward_chain_context_tests.jl

ForwardChainContext exact positive binding                              30/30 pass
ForwardChainContext rejects candidate, registry, Genome, graph          9/9 pass
ForwardChainContext rejects mission, bounds, scope, subject             11/11 pass
ForwardChainContext scenario membership and exact batch order            8/8 pass
ForwardChainContext validators recompute sealed bodies                  14/14 pass
Total                                                                   72/72 pass
Exit code                                                               0
```

Closest unchanged regressions:

```text
julia --project=. test/runtime_v4_core_tests.jl
RuntimeV4 contracts and exact capability closure                        20/20 pass
RuntimeV4 hash derivation, cache and fail-closed execution                6/6 pass
Total                                                                   26/26 pass
Exit code                                                               0

julia --project=. test/runtime_v4_spine_tests.jl
frozen StageSpec derives Cartesian gaps                                 11/11 pass
admission and closure are separate                                      11/11 pass
spine reports unresolved provider coverage                                6/6 pass
typed evidence binding closes exact Cartesian scope                     21/21 pass
prerequisite closure is typed and P5 stays withheld                       5/5 pass
Total                                                                   54/54 pass
Exit code                                                               0
```

Runnable example:

```text
julia --project=. examples/runtime_v4_forward_chain_context.jl

contexts=2
compilation_status=prefix_incomplete
unresolved_nonterminals=1
emits_evidence=false
terminal_authority=false
Exit code=0
```

The printed context hash was
`7ccf05db74910add0646c34588d0cbf174a2b65d3cefad87713a4534749b5b78`
for this exact fixture and source state.

## Authority boundary

The accepted result is a structural identity contract only. It does not accept
multi-region coupling, a diffusion provider, engineering/control/fault closure,
validation/UQ, physical evidence, whole-device closure, or any terminal
classification. Credible physical-device count is unchanged.
