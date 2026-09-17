# UP2-01 pre-T0 TypedCompilerIRV1/LoweringV1 independent review R2

Date: 2026-09-17 (Asia/Shanghai). This is a different-Luna static review of
the additive R2 repair. Julia/DESC and the executable Julia contract test were
not run in this lane.

## Verdict and ceiling

**GO for the additive pre-T0 contract-only slice; NO-GO for formal UP2-01
acceptance.** The three R1 implementation blockers are closed in source and
the static QA receipt is `84/84`, exit `0`. The maximum status remains
`contract_only/prepared`, with `not_measured`; no compiler, mesh, provider,
solver, numerical, physical, engineering, T0/T1/T2, or R01-R10 credit is
granted.

## Boundary and evidence

The four reviewed source/test files are additive. `FusionConceptAI.jl`, the
shared runtime entry, task manifest, registry, and existing product tests are
not modified. The permitted static command is:

```text
python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py
exit=0, checks=84, passed=84, errors=[]
```

The test source directly includes the two additive files and contains actual
`@test`/`@test_throws` assertions; it does not construct the shared runtime or
invoke a provider, mesh, solver, or physical lane. Because Julia was not run,
this is a source-and-test audit, not runtime execution evidence.

## Independent checks

- **Expected units: PASS.** `TypedCompilerBindingV1` carries typed input and
  output units. `_tc_unit_equal_v1` compares name, all seven exponents, and
  exact scale (`isequal`); both IR units are compared with the expected
  binding. The test changes expected units and asserts `:unit_mismatch` and
  `:fail_closed`.
- **Schema/revision: PASS.** The validator compares both IR fields to
  `_TCIR_SCHEMA_V1` and `_TCIR_REVISION_V1`; the test mutates each and asserts
  `:schema_mismatch`/`:revision_mismatch` with `:fail_closed`.
- **Sealed authority: PASS.** `TypedCompilerSourceAuthorityV1` has a sealed
  inner constructor and a fixed factory for checked-present authority. It
  carries schema, revision, receipt, candidate, owner, region, chart,
  operator, source, conservation, input unit, and output unit.
- **Full authority binding: PASS in validator.** The validator loops over all
  seven cross-layer refs and requires each authority field to equal both IR
  and expected binding; it separately requires both authority units to equal
  IR and expected units. Schema, revision, checked-present status, and a
  nonempty receipt are also required.
- **Status classification: PASS.** A local source with no authority is
  `terminal_deferred` via `:source_authority_absent`; checked-present exact
  authority is `ready`; schema, revision, unit, ref, status, operator, source,
  conservation, and scope contradictions are `fail_closed`.
- **Synthetic ceiling: PASS.** Constructor and lowering preserve
  `contract_only`, `not_measured`, and `measured=false`; synthetic IR cannot
  carry local authority. Lowering forwards operations only for `ready` and
  emits no execution.

## Evidence caveat

The test directly exercises authority operator and input-unit mutations and
the implementation visibly checks the remaining authority fields in one
explicit loop. It does not contain separate runtime cases for authority
candidate, owner, region, chart, source, conservation, output-unit, schema,
and receipt mutations. This is a test-matrix strengthening opportunity, not a
source-binding gap; a future Julia lane should expand those cases before
formal promotion.

`validate_typed_compiler_lowering` rejects post-construction receipt drift by
throwing an `ArgumentError`; this is outside the current pre-T0 construction
surface and does not raise the contract-only ceiling, but should be converted
to a typed fail-closed receipt if mutable/tamper-facing APIs are later added.

The prior R1 review and R2 agent-local record remain unchanged; this is an
independent review archive.
