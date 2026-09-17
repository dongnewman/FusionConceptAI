# UP2-01 pre-T0 TypedCompilerIRV1/LoweringV1 independent review R1

Date: 2026-09-17 (Asia/Shanghai). Reviewer lane: independent static review.
This review covers the additive pre-T0 contract slice only. Julia, DESC,
providers, meshes, solvers, and physical execution were not invoked.

## Verdict

**NO-GO for acceptance; changes requested.** The static boundary is suitable
for an early-preparation contract-only slice, but the current validator does
not yet establish the claimed strict typed binding or checked local-source
authority. The status ceiling remains `contract_only/prepared`; this is not a
formal UP2-01 acceptance.

## Evidence and boundary

The source and test surface is additive: `TypedCompilerIRV1.jl`,
`TypedCompilerLoweringV1.jl`, the isolated UP2 pre-T0 contract test, and its
static QA script. `FusionConceptAI.jl`, shared registry/manifest, and existing
product tests are untouched. Static QA was rerun from the recorded command:

```text
python -B test/RuntimeV4/UP2PreT0/static_qa_typed_compiler_ir_v1.py
exit=0, checks=65, passed=65, errors=[]
```

The lexical/static evidence shows no compiler execution, field lowering, mesh
construction, provider call, solver, convergence, conservation, numerical,
physical, or engineering path. This is a boundary check, not runtime proof;
the Julia contract test was not run in this lane.

Sealed inner constructors are present for the public unit, binding, IR, and
lowering-plan surfaces, and the contract rejects empty/wildcard text,
malformed units, empty operations, measured claims, and foreign binding refs.
Those findings are PASS for construction sealing and basic structural safety.

## Findings

1. **F1 — PARTIAL / strict unit binding is not established.** The expected
   binding contains no expected input/output units. Validation checks only
   unit shape, seven exponents, finite positive scale, and rank; it does not
   compare either unit with a declared typed operator/source/conservation
   contract, or even bind them to an expected unit declaration. The current
   “bad unit plus illegal operation” test asserts the illegal operation only,
   so it does not prove a unit contradiction is rejected.

2. **F2 — FAIL / schema and revision are not authority-bound.** The validator
   does not compare `ir.schema` or `ir.revision` with the v1 constants. A
   mutated/foreign schema or revision can therefore reach `ready`. Add direct
   mutation negatives with an asserted `fail_closed` result.

3. **F3 — FAIL / local source can become ready without checked authority.**
   `source_kind=:local_source`, `synthetic=false`, and any non-absent
   `source_ref` can validate as `ready`; there is no typed checked-present
   authority receipt/status. `typed_absent` correctly produces
   `terminal_deferred`, but “present-looking” text is not evidence. Before
   T0 closure, either force factories to synthetic declarations or require an
   explicit checked-present local-source receipt and return
   `terminal_deferred` when it is missing. Never promote this path from text
   alone.

4. **F4 — PARTIAL / semantic cross-field binding.** Exact candidate, owner,
   region, chart, operator, source, and conservation refs are compared with
   the expected binding, and foreign-ref negatives are real assertions. The
   validator does not yet verify that operation signatures and units agree
   with the referenced operator/source/conservation declaration; this is
   acceptable only as a clearly bounded pre-T0 contract gap.

5. **F5 — PARTIAL / negative-test coverage.** The existing tests exercise
   constructor invariants and foreign refs, plus the typed-absent deferred
   path. They do not actually assert failure for schema/revision mutation,
   output/input unit mismatch against an expected typed declaration, or
   local-source authority absence. These must be added before a GO verdict.

6. **PASS with ceiling — synthetic evidence labels.** Synthetic fixtures
   enforce `claim_ceiling=:contract_only`, `evidence_scope=:not_measured`, and
   `measured=false`; lowering emits no executable work and only forwards
   operations for a structurally ready declaration. This must remain true
   after the fixes.

## Required minimum for re-review

Additive fixes should (a) bind schema/revision to the v1 declaration, (b) add
typed expected input/output units or an equivalent declaration and reject
unit/operator/source/conservation contradictions, and (c) represent checked
local-source authority explicitly so missing/typed-absent authority is
`terminal_deferred`, while contradictions remain `fail_closed`. Add executable
contract assertions for each of these mutations and preserve the existing
`contract_only/not_measured` and no-execution boundary.

## State ceiling

Current result: `contract_only`, `not_measured`, `formal_acceptance=false`,
`accepted=false`, status ceiling `prepared`/`terminal_deferred` as applicable.
No UP2-01 completion, parent/T0/T1/T2 acceptance, B01/B04, mesh/provider/
solver/numerical/physical/engineering evidence, or R01-R10 credit is granted.

The prior `agent_local_r1` report/manifest are left untouched; this document
is an independent review record only.
