# UP2 pre-T0 TypedCompilerIR/Lowering R2

This is an additive contract-only repair of the prior independent R1 NO-GO
findings. Julia/DESC, compiler, provider, mesh, solver, numerical, physical,
and engineering execution were not invoked.

## Repairs

- `TypedCompilerBindingV1` now declares typed input/output units and the IR
  validator compares name, seven exponents, and scale exactly.
- Schema and revision are validator-bound to `_TCIR_SCHEMA_V1` and
  `_TCIR_REVISION_V1`; foreign mutations are `fail_closed`.
- `TypedCompilerSourceAuthorityV1` is a sealed checked-present receipt carrying
  schema, revision, status, receipt ref, all cross-layer refs, and both units.
  A `:local_source` IR with only a non-empty source ref remains
  `terminal_deferred`; it becomes `ready` only with an authority receipt whose
  every field exactly matches the IR and expected binding. Authority/status,
  operator, source, conservation, and unit contradictions are fail-closed.
- Synthetic defaults remain `contract_only`, `not_measured`, and
  `measured=false`; lowering remains declaration-only.

## Static evidence

`python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` returned
`84/84` checks with no errors. No Julia/DESC command was run. The isolated
contract test contains real assertions for schema/revision mutation, exact
unit mismatch, local-source missing authority (`terminal_deferred`), checked
present authority (`ready`), authority field/status contradictions, and
operator/source/conservation mismatches.

This remains `contract_only / not_measured / accepted=false`; it does not
grant compiler, mesh, provider, solver, physical, engineering, T0/T1/T2, or
R01--R10 credit.
