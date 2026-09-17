# UP2 pre-T0 TypedCompilerIR/Lowering R5 independent review

Date: 2026-09-17 (Asia/Shanghai). This is a read-only independent static
review of the R5 source-kind/synthetic consistency repair. No product or test
file was modified, no Julia/DESC/compiler/provider/mesh/solver command was
run, and no commit was created.

## Verdict and status ceiling

**GO for contract-only/prepared; NO-GO for formal UP2 acceptance.** The
constructor now enforces the complete two-way invariant
`synthetic == (source_kind === :synthetic)`, and the source/test slice covers
all four truth quadrants plus local-source authority outcomes. The status
ceiling remains `contract_only / not_measured / accepted=false`; no T0/T1/T2,
numerical, physical, engineering, or R01--R10 credit is granted.

## Static QA

Command executed:

```text
python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py
exit=0; checks=107; passed=107; errors=[]
```

The checker is text/hash-only and does not invoke Julia, DESC, a compiler,
provider, mesh, or solver.

## Focused review

### Complete source-kind/synthetic truth table

The sealed `TypedCompilerIRV1` inner constructor at source lines 238--247
accepts exactly the following pairs:

| `source_kind` | `synthetic` | Result |
|---|---:|---|
| `:synthetic` | `true` | accepted |
| `:synthetic` | `false` | rejected |
| `:local_source` | `true` | rejected |
| `:local_source` | `false` | accepted |

This is implemented by the explicit equality
`synthetic == (source_kind === :synthetic)`, not by a one-way implication.
The test exercises both accepted quadrants and both rejecting quadrants at
`typed_compiler_ir_v1_contract_tests.jl:137--147`.

### Local-source deferred and authority recheck

`source_kind=:local_source, synthetic=false` is constructible. Without a
source authority, validation remains `:terminal_deferred` with
`:source_authority_absent`; with the sealed checked-present authority, the
same local IR reaches `:ready` after exact authority/binding checks. The
existing tests retain both paths at lines 166--180 and explicitly verify the
authority status and lowering result. Foreign or unchecked authority remains
`:fail_closed`.

### Similar Boolean guards

The remaining `&& ... || throw` expressions are direct validity predicates
(text/tuple shape, unit dimensions, finite positive scale, allowed source kind,
measured=false, and lowering measured=false). The validator's
`ir.synthetic && ir.source_kind == :synthetic` is a one-sided diagnostic
predicate for already sealed values; constructor equality makes inconsistent
values unreachable through the public API. No analogous implication bug was
found in the typed compiler or lowering files.

### Boundary and receipts

The R4 failure receipt remains preserved at
`runs/agent_local_up2_tcir_contract_matrix_20260917_r4/` and in
`docs/implementation/UP2-01/contract_only/agent_local_r5/manifest.json`.
Its metadata records `exit_code=1`, `71 pass / 1 error`,
`hashes_unchanged=true`; the root cause was the former
`synthetic && source_kind == :synthetic` guard rejecting the valid local-source
construction. R5 does not overwrite this historical receipt.

## Current input hashes

The following values were recomputed and match `agent_local_r5/manifest.json`:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/TypedCompilerIRV1.jl` | 25159 | `f684647aa1223c6f127b14ee3e90baa790fac272046cae3c62ecf500c50302f8` |
| `src/RuntimeV4/TypedCompilerLoweringV1.jl` | 3932 | `452758e71f6bb8d50257dad77e39fd3ec1e2aea81830d838fa93cb144b0f427c` |
| `test/RuntimeV4/UP2PreT0/typed_compiler_ir_v1_contract_tests.jl` | 12568 | `7ab20ac0745d7242d7beeb0dd0381bac3eb40b9b7290f8101b7a58e0dff42a01` |
| `test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` | 5447 | `7bf5167698117f55e2af045d1f55bbbfd136be3c90c88d0425f955d17f3e3152` |

The shared runtime entry remains outside this additive slice. This review
does not promote the contract to executable compiler, numerical, physical, or
whole-device evidence; a serialized parent lane must still run the isolated
Julia test once before any later gate.
