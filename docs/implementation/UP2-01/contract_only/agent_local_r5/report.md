# UP2 pre-T0 TypedCompilerIR/Lowering R5

This is a minimal boolean-consistency repair after the serialized R4 parent
diagnostic. The R4 failure receipt is preserved by reference:
`runs/agent_local_up2_tcir_contract_matrix_20260917_r4`, exit `1`, `71 pass /
1 error`, `2.4s`, with hashes unchanged. The failure occurred while building
a local-source factory value at the inner constructor: the old expression
`synthetic && source_kind == :synthetic || throw` incorrectly required every
IR to have `synthetic=true`.

## Repair

The constructor now uses the explicit two-way invariant
`synthetic == (source_kind === :synthetic)`: synthetic/source-kind pairs
`(true, :synthetic)` and `(false, :local_source)` are accepted, while
`(false, :synthetic)` and `(true, :local_source)` are rejected. Existing local
source authority validation remains downstream and unchanged. A static audit
of the remaining boolean guard expressions found no analogous implication
mistake; the remaining guards are direct validity predicates.

The isolated test adds all four source-kind/synthetic quadrants and retains
the local checked-present authority ready path and terminal-deferred missing
authority path.

## Static evidence and boundary

`python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` returned
`107/107` checks with no errors. Text/static audit passed. No Julia, DESC,
compiler, provider, mesh, solver, numerical, physical, or engineering
execution was run. This remains `contract_only / not_measured / accepted=false`;
runtime confirmation is deferred to the serialized parent lane and no T0/T1/T2
or R01--R10 credit is claimed.
