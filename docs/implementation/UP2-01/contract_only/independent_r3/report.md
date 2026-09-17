# UP2 pre-T0 TypedCompilerIR/Lowering R3 independent review

Date: 2026-09-17 (Asia/Shanghai). This is an independent static review of
the additive R3 constructor-dispatch repair. No product or test file was
modified by this review. Julia, DESC, compiler, provider, mesh, solver,
numerical, physical, and engineering execution were not run.

## Verdict and status ceiling

**GO for contract-only/prepared; NO-GO for formal UP2 acceptance.** The
five sealed product types have exact typed factory dispatch through private
`invoke` wrappers, the public unsealed constructors reject direct calls, and
the contract test source contains factory-success and direct-rejection
assertions for all five types. The R3 static QA returned `100/100`, exit
`0`. The maximum status remains `contract_only / not_measured`; no T0/T1/T2
or R01-R10 credit is granted.

## Exact sealed factory review

The source contains the following seal-bearing inner constructors and matching
private wrappers. Each wrapper's `invoke` tuple includes `_TypedCompilerSealV1`
followed by exactly the inner constructor's declared argument types:

| Product | Factory wrapper and exact typed dispatch | Public direct-call guard |
|---|---|---|
| `TypedCompilerUnitV1` | `_tc_new_unit_v1`; `String, NTuple{7,Int}, Float64` | `TypedCompilerUnitV1(args...) = throw(ArgumentError(...))` |
| `TypedCompilerBindingV1` | `_tc_new_binding_v1`; seven `String` fields followed by two `TypedCompilerUnitV1` values | same catch-all rejection |
| `TypedCompilerSourceAuthorityV1` | `_tc_new_source_authority_v1`; `String, String, Symbol`, nine `String` fields, then two typed units | same catch-all rejection |
| `TypedCompilerIRV1` | `_tc_new_ir_v1`; nine `String` fields, two typed units, `Tuple{Vararg{String}}`, `Symbol`, two `Bool`, two `Symbol`, and `Union{Nothing,TypedCompilerSourceAuthorityV1}` | same catch-all rejection |
| `TypedCompilerLoweringV1` | `_tc_new_lowering_v1`; `TypedCompilerIRV1`, `TypedCompilerValidationV1`, `Tuple{Vararg{String}}` | same catch-all rejection |

The test directly calls every public constructor without the private seal and
asserts `ArgumentError`; it also asserts each corresponding factory returns
the expected product type. The R3 factory path is therefore source/test
covered even though this review intentionally does not execute Julia.

## Contract and negative-case checks

- Schema/revision constants, seven-dimensional units, and complete
  candidate/owner/region/chart/operator/source/conservation bindings remain
  validated.
- Local source without checked-present authority remains
  `terminal_deferred`; contradictory authority or cross-layer references are
  `fail_closed`.
- Synthetic declarations remain `contract_only`, `not_measured`, and
  `measured=false`; no provider, mesh, solver, or physical claim is reachable
  from this additive slice.
- Test source has actual assertions for factory success, direct constructor
  rejection, schema/revision/unit mismatch, typed-absent/deferred source,
  local authority, illegal inputs, and binding/operator/source/conservation
  contradictions.

## Static evidence and hash audit

Command executed:

```text
python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py
exit=0; checks=100; passed=100; errors=[]
```

The current SHA-256 values exactly match
`agent_local_r3/manifest.json` for all four owned source/test files:

```text
src/RuntimeV4/TypedCompilerIRV1.jl
b1a3142db83035ef623bcf175afa67eee17d6e75cf1ce248c85475d0559b4e78
src/RuntimeV4/TypedCompilerLoweringV1.jl
452758e71f6bb8d50257dad77e39fd3ec1e2aea81830d838fa93cb144b0f427c
test/RuntimeV4/UP2PreT0/typed_compiler_ir_v1_contract_tests.jl
abb0cb6b9aada1a7ef43d739e5d56026f55a1403cecffd15b14fe6f4c37c0b83
test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py
ad3be091ca44ff01ccd5f7e9d9cfcb9ca392120f4aac1ee87fad7f67ef512aa7
```

The preserved R2 failure receipt remains at
`docs/implementation/UP2-01/contract_only/agent_local_r3/manifest.json` and
records the pre-repair constructor failure (`0 pass / 1 error`,
`TypedCompilerUnitV1 sealed constructor`) with its frozen R2 hashes. It has
not been overwritten by the current R3 hashes.

## Remaining gate

This review cannot promote the slice beyond contract-only. The serialized
parent lane must still run the isolated Julia contract test and independently
confirm all factory paths at runtime. Formal UP2 requires the authority and
compiler execution gates after T0/T1/T2; this archive grants no numerical,
physical, engineering, or parent-goal credit.
