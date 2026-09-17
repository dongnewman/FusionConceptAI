# UP3 composition matcher contract-only R1

This additive slice defines a deterministic typed port/capability matcher and
composition DAG plan. It performs no provider, solver, mesh, Julia/DESC, or
physical execution. It does not alter the manufactured M4/M5 lanes, the shared
capability registry, the task manifest, or the T0/T1/T2 status.

## Scope

- full typed capability signature compatibility;
- deterministic edge and topological-order generation;
- ambiguity and cycle rejection;
- source/return ledger closure checks;
- label/permutation-independent identity intent;
- explicit provider/solver invocation counts fixed at zero;
- `contract_only`, `terminal_deferred`, and `fail_closed` states.

## Static verification

The permitted check is:

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
```

The Julia test is a frozen future execution contract and was not run in this
lane. A future execution must construct real typed `CapabilitySignatureV4`
ports and independently exercise every fixture negative; this archive is not
UP3-01 acceptance and grants no B01/B02/B04/B08, provider, solver, numerical,
physical, engineering, or R01-R10 credit.

## Future handoff

After UP2-05 provider capability registration and the formal UP3 dependency
chain are complete, the same matcher must feed a common execution entry. A
real build/holdout matrix must then prove residual, KCL/KVL, source-return and
energy conservation, coupling response, and provider-dropout behavior. Until
then the maximum status remains `contract_only/prepared`.
