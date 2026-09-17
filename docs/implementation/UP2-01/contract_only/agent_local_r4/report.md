# UP2 pre-T0 TypedCompilerIR/Lowering R4

This is a minimal concrete-string normalization repair after the serialized
R3 parent diagnostic. The R3 failure receipt is preserved by reference:
`runs/agent_local_up2_tcir_contract_matrix_20260917_r3`, direct diagnostic
exit `1`, `0 pass / 1 error`, `1.3s`, with the R3 input hashes unchanged. The
error was `_tc_new_unit_v1(::SubString{String}, ...)`; `strip` in
`_tc_text_v1` returned a `SubString`, which could not enter the wrapper's
concrete `String` dispatch.

## Repair

`_tc_text_v1` now closes its successful result with
`String(strip(String(value)))`. The five private factory wrappers normalize
their textual arguments before the seal-bearing `invoke`; IR operation values
are normalized into `Tuple{Vararg{String}}` as well. This preserves the sealed
public direct-constructor rejection and keeps whitespace trimming explicit in
the factory contract.

The isolated test now asserts trimmed unit/binding/IR fields have exact
`String` type, operation tuple members are concrete `String`, factory success
still holds, and every direct unsealed constructor remains rejected.

## Static evidence and boundary

`python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` returned
`105/105` checks with no errors. Text/static wrapper audit passed. No Julia,
DESC, compiler, provider, mesh, solver, numerical, physical, or engineering
execution was run. This remains `contract_only / not_measured / accepted=false`;
runtime confirmation is deferred to the serialized parent lane and no T0/T1/T2
or R01--R10 credit is claimed.
