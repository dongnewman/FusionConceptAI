# UP2 pre-T0 typed compiler IR contract-only R1

Date: 2026-09-17 (Asia/Shanghai). This is an additive, pre-T0 structural
contract slice. It does not modify `Compiler.jl`, `FusionConceptAI.jl`, the
Field/Spatial/Conservative modules, the task manifest, or any existing test.

## Scope and ceiling

The new `TypedCompilerIRV1.jl` and `TypedCompilerLoweringV1.jl` files define a
sealed typed declaration surface for candidate, owner, region, chart, operator,
source, conservation, units, and ordered operations. The validator is strict
and fail-closed: valid declarations report `status=ready`; typed-absent source
authority reports `terminal_deferred`; contradictions and illegal operations
report `fail_closed`.

The lowering output is a declaration-only plan. Synthetic fixtures are always
`claim_ceiling=contract_only`, `evidence_scope=not_measured`, and
`measured=false`. No compiler execution, field lowering, mesh construction,
provider call, solver, convergence, conservation, numerical, physical,
engineering, search, UP2, or R01–R10 credit is claimed.

## Evidence

- Static QA: [static_qa_typed_compiler_ir_v1.py](../../../../../test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py), exit `0`, `65/65` checks, `errors=[]`.
- Machine receipt: [manifest.json](manifest.json).
- Julia contract tests are authored at
  `test/RuntimeV4/UP2PreT0/typed_compiler_ir_v1_contract_tests.jl` but were not
  run under this bounded lane.
- Julia/DESC/provider/mesh/solver were not invoked; no product/test integration
  was performed and no commit was made.

This record is `accepted_local_contract` only for the additive software
contract and static boundary; the Julia contract test remains unrun. It does
not change the UP2 gate or any parent/T0/T1/T2 authority.
