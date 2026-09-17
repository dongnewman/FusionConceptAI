# UP4 inverse realization request contract-only R1

## Delivery

Added one isolated request contract, one Julia test specification, one JSON
fixture, and a read-only Python static QA runner.  The contract carries typed
target/source/return ports, exact units and function spaces, exact domains,
finite ordered bounds, electrical power/current/voltage bounds, EMF policy,
material and geometry declarations, provider capability declarations, and
canonical identity.

## Boundary decisions

- Contradictory target/return, unit, function-space, domain, bound, or voltage
  EMF declarations return `fail_closed`.
- Missing return, provider capability, derivative order, material model, or
  geometry model returns `terminal_deferred`.
- A complete positive declaration returns `prepared` with
  `claim_ceiling=:contract_only`; no provider, derivative, solver, hardware,
  DESC, optimizer, or registry call is made.
- Provider capability collections are sorted before request identity, so input
  ordering does not change the canonical hash.
- This slice grants no UP4 execution, engineering, physical, provider, solver,
  B07A/B07B, or R01-R10 credit.

## QA boundary

The Julia test was not executed by this agent.  The only QA command was the
read-only Python static checker, which exited 0 with empty stderr.  Its raw
outputs are `static_qa.stdout.raw` and `static_qa.stderr.raw`; this pass is
not runtime acceptance.

Static-QA input hashes:

| path | SHA-256 |
|---|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `1cde7d4640534f8accd9e5946b87bbdc7e998c1be1acc4445b5d8dc8460c4d5d` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `9bed224889b3faa0fdc19eff951741b9e98c94520cbdebdf5beef8e8cd9884b5` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `37a5238359a2f28182e0cf68e6d60726afe80654776d91c5a850d1c7473f4996` |
