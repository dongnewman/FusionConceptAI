# Engineering/control/fault contract report — 2026-09-09

## Scope

Implemented the bounded forward engineering/control/fault contract in
`src/RuntimeV4/EngineeringControlFaultContracts.jl`, with ownership limited
to this file, its focused test, and the implementation/report documents.

## Extract and wrap decisions

The current typed RuntimeV4 contract style and the three-contract registry
were retained.  The legacy `outputs/fusion_concept_ai` material was used only
to preserve boundaries: historical engineering, dynamic-fault, material, and
static-margin artifacts are evidence references, not runtime authority.
No legacy Genome type, authority route, family route, or candidate preference
was imported.  No control/manufacturing result is promoted to physical proof.

## Contract and validator result

The module binds `MechanismGenomeV4`, `FieldGeometryGenomeV4`, and
`RealizationControlGenomeV4` to one `GenomeContractRegistryV4`, records loads,
observation/actuation dependencies, fault recovery scenarios, and typed
evidence obligations, then emits a hash-checked decision.  Required missing
capabilities remain `:unsupported`; missing/unknown evidence remains
`:deferred`; overload is `:fail`.  Physical obligations are independently
tracked by `physical_evidence_satisfied`.

## Test result

Focused command:

```text
julia --project=. test/runtime_v4_engineering_control_fault_contract_tests.jl
```

Result: **PASS**, 2 testsets and 12 individual checks, exit code 0.
The test covers registry/G1-G2-G3 binding, canonical hash integrity, deferred
physical evidence, overload failure, and recoverable unsupported capability.

## Gaps and integration hook

This module does not claim measured engineering margins, manufacturing
qualification, hardware actuation, or fault-injection evidence.  The next
integration hook is an explicit caller-side `Base.include` (or a future
aggregator include) followed by `validate_engineering_control_fault(input)`;
the aggregator was intentionally not modified in this change.
