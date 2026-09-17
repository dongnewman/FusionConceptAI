# UP3 CompositionMatcher contract-only R2 delivery

Date: 2026-09-17 (Asia/Shanghai).

## Result

The R2 additive slice is **static-QA PASS** and addresses the independent R1
blockers. The shared `FusionConceptAI.jl` entry, capability registry, task
manifest, manufactured lanes, and R1 archive were not changed. Julia/DESC were
not run and no provider, mesh, solver, numerical, physical, or engineering
claim is made.

## Implemented contract boundary

- The test includes the source into a dedicated
  `CompositionMatcherIsolatedV1` module and calls the qualified matcher and
  validator APIs directly; it does not use the shared entry to inspect hidden
  symbols.
- The executable replay includes a two-input/two-edge composition, so input
  tuple permutation is exercised rather than only inferred from a one-port
  fixture.
- Canonical component/port identity uses every typed signature, physical,
  unit, space/domain, interface, and ledger field while excluding display
  `port_id`. Components, ports, edges, unresolved keys, failures, and ledger
  records are normalized and sorted. Component/input permutation and label
  renaming therefore replay to the same input and plan hashes.
- Structural no-match, ambiguity, duplicate component, unclosed ledger, and
  invalid component/input conditions return a typed `fail_closed` plan.
  Construction-only type invariants remain explicit `ArgumentError`s.
- Missing/out-of-domain provider and `typed_absent` authority are represented
  as deferred reasons and produce `terminal_deferred`, not `fail_closed`.
- `validate_composition_match` independently recomputes edges, topological
  order, ledger defects, status, input hash, and plan hash. Any drift or
  nonzero invocation count returns a typed fail-closed validation plan.
- Provider and solver invocation counts remain fixed at zero; no execution
  primitive is present.

## Test/static evidence

The independent Julia contract test now covers a positive edge plan,
label/permutation erasure, space mismatch, ambiguity, provider dropout,
typed-absent authority, unclosed ledger, duplicate component, invalid component,
invalid input, validator tampering, and construction-time rejection. The
fixture retains nine named negative classes.

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0
PASS static_qa_composition_matcher_contract_v1_r2
```

The Julia test was intentionally not executed. The maximum state is
`contract_only/prepared`; no UP3-01/UP3 formal acceptance, B01/B02/B04/B08,
provider/solver, conservation, convergence, numerical, physical, engineering,
or R01-R10 credit is granted.
