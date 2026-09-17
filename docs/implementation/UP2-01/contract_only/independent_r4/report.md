# UP2 pre-T0 TypedCompilerIR/Lowering R4 independent review

Date: 2026-09-17 (Asia/Shanghai). This is a read-only independent static
review of the R4 concrete-`String` repair. No product or test file was
modified, no Julia/DESC/compiler/provider/mesh/solver command was run, and no
commit was created.

## Verdict and status ceiling

**GO for contract-only/prepared; NO-GO for formal UP2 acceptance.** The
implementation closes the R3 `SubString` dispatch failure statically, retains
sealed direct-constructor guards, and has source/test coverage for the five
factory products. The status ceiling remains
`contract_only / not_measured / accepted=false`; this review grants no T0,
T1, T2, numerical, physical, engineering, or R01--R10 credit.

## Static QA

Command executed:

```text
python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py
exit=0; checks=105; passed=105; errors=[]
```

The checker is text/hash-only and explicitly does not invoke Julia, DESC,
providers, meshes, or solvers.

## Focused checks

### Concrete text and tuple closure

`_tc_text_v1` accepts `AbstractString`, converts to `String` before `strip`,
and returns the concrete `String` result (`TypedCompilerIRV1.jl:26--36`).
Every text-bearing factory wrapper calls this helper before its sealed
`invoke`. `_tc_tuple_text_v1` maps each operation through the same helper and
returns a duplicate-free tuple; `TypedCompilerIRV1.operations` is declared as
`Tuple{Vararg{String}}` (`:39--45`, `:210`). The IR factory test asserts both
trimmed values and exact `String` element types (`typed_compiler_ir_v1_contract_tests.jl:47--72`).

Whitespace success is statically covered for Unit, Binding, and IR fields and
IR operations. The SourceAuthority factory also converts its arguments to
`String` before the helper (`TypedCompilerIRV1.jl:180--195`), although the
test does not include a separate whitespace-only SourceAuthority assertion;
this is a coverage improvement, not a source dispatch defect.

### Five exact sealed factory dispatches

The inner constructor signatures and private wrappers match exactly:

| Product | Private wrapper | Exact sealed dispatch after `_TypedCompilerSealV1` |
|---|---|---|
| `TypedCompilerUnitV1` | `_tc_new_unit_v1` | `String, NTuple{7,Int}, Float64` |
| `TypedCompilerBindingV1` | `_tc_new_binding_v1` | seven `String` fields, then two `TypedCompilerUnitV1` |
| `TypedCompilerSourceAuthorityV1` | `_tc_new_source_authority_v1` | `String, String, Symbol`, eight post-status `String` fields, then two typed units |
| `TypedCompilerIRV1` | `_tc_new_ir_v1` | nine `String` fields, two typed units, `Tuple{Vararg{String}}`, `Symbol`, two `Bool`, two `Symbol`, optional typed authority |
| `TypedCompilerLoweringV1` | `_tc_new_lowering_v1` | `TypedCompilerIRV1, TypedCompilerValidationV1, Tuple{Vararg{String}}` |

The five public direct constructors have catch-all `ArgumentError` guards, and
the contract test contains direct unsealed rejection assertions for all five
products (`typed_compiler_ir_v1_contract_tests.jl:98--126`). The factory path
also has corresponding success assertions.

### R3 failure receipt and current hashes

The R3 failure remains preserved in both the run directory
`runs/agent_local_up2_tcir_contract_matrix_20260917_r3/` and the R3 archive
manifest. Its recorded failure is `0 pass / 1 error`, caused by
`_tc_new_unit_v1(::SubString{String}, ...)`; the run metadata records
`hashes_unchanged=true`. R4 does not overwrite that receipt.

Current files match the R4 agent-local manifest:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/TypedCompilerIRV1.jl` | 25165 | `b09e323411c71fe005d086e08d42186fdd6febdb50898891b99002a408364d6a` |
| `src/RuntimeV4/TypedCompilerLoweringV1.jl` | 3932 | `452758e71f6bb8d50257dad77e39fd3ec1e2aea81830d838fa93cb144b0f427c` |
| `test/RuntimeV4/UP2PreT0/typed_compiler_ir_v1_contract_tests.jl` | 11861 | `8ed95ba3f86f00d10a0b3de56ad8f836226997182b2bfdd937f41275cc1bca1a` |
| `test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py` | 5337 | `c7594e4a6a2aeafad56ccc068e2ee2fc5b53bed2f003b4cf09d0f6b8f9667241` |

## Boundary and next gate

This is a structural declaration/lowering plan only. Synthetic data remains
`contract_only`, `not_measured`, and `measured=false`; typed-absent local
source remains deferred, while authority/binding contradictions are
fail-closed. The serialized parent lane may run the isolated Julia contract
test once, then independently preserve its runtime receipt. Formal UP2 still
requires the later T0/T1/T2 execution gates and must not be inferred from
this static GO.
