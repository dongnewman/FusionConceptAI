# UP2 pre-T0 TypedCompilerIR/Lowering R3

This additive contract-only repair closes the R2 constructor-dispatch defect.
The R2 direct diagnostic was archived here as a failure receipt before the
repair: command `julia --project=. --startup-file=no --history-file=no
test/RuntimeV4/UP2PreT0/typed_compiler_ir_v1_contract_tests.jl`, exit `1`,
`0 pass / 1 error`, `0.7s`, error `TypedCompilerUnitV1 sealed constructor`,
at HEAD `23baee9`. Its frozen R2 input hashes are preserved in
`manifest.json` and were not overwritten.

## Repair

The five sealed product types retain their public catch-all constructors that
reject unsealed direct construction. Each factory now calls a narrow private
typed wrapper using `invoke` to select the seal-bearing inner constructor:
`_tc_new_unit_v1`, `_tc_new_binding_v1`, `_tc_new_source_authority_v1`,
`_tc_new_ir_v1`, and `_tc_new_lowering_v1`. This prevents the public rejection
method from swallowing legitimate factory construction while keeping the
sealed boundary closed. The mutation/rebuild helpers in the isolated test use
the same private wrappers, and tests cover factory success plus direct
unsealed rejection for every sealed type.

## Static evidence and boundary

`python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` returned
`100/100` checks with no errors. `git diff --check` passed for the owned
files. No Julia, DESC, compiler, provider, mesh, solver, numerical, physical,
or engineering execution was run. This remains
`contract_only / not_measured / accepted=false`; no T0/T1/T2 or R01--R10
credit is claimed. Runtime confirmation of the factory path remains for the
serialized parent diagnostic lane.
