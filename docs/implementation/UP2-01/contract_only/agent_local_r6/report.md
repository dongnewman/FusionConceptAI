# UP2 pre-T0 TypedCompilerIR/Lowering R6

This is a minimal validator-consistency repair after the serialized R5 parent
diagnostic. The R5 failure receipt is preserved by reference:
`runs/agent_local_up2_tcir_contract_matrix_20260917_r5`, exit `1`, `83 pass /
5 fail`, `3.5s`, with hashes unchanged. The constructor quadrants had been
fixed, but the validator still used the old one-way guard
`ir.synthetic && ir.source_kind == :synthetic`, so every local-source IR was
reported `fail_closed`.

## Repair

The validator now uses the same explicit two-way invariant as the sealed
constructor: `ir.synthetic == (ir.source_kind === :synthetic)`. Thus
synthetic/true validates ready, local_source/false validates terminal-deferred
without authority or ready with a checked-present authority, while the two
invalid quadrants are rejected at construction. Lowering was audited and has
no source-kind/synthetic guard.

The isolated test now covers all four quadrants across construction and
validation and retains the local authority downstream path.

## Static evidence and boundary

`python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` returned
`108/108` checks with no errors. Boolean-guard and text hygiene audits passed.
The serialized runtime receipt is now archived under `runtime/`: the direct
Julia command exited `0`, reported `89/89` in `1.6s`, had empty stderr, and
pre/post input hashes were equal. This runtime success validates only the
isolated contract-only test; it does not grant formal UP2, T0, or R credit.
Previous R3, R4, and R5 failure receipts remain retained and are listed in
`manifest.json`. No DESC, compiler, provider, mesh, solver, numerical,
physical, or engineering execution was performed. The status remains
`contract_only / accepted=false`.
