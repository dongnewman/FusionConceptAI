# AD-41 UP1 remaining gate audit — repair R1

Date: 2026-09-15  
Repair round: `repair_r1`  
Repair scope: scheduling wording only  
Original audit: `docs/implementation/AD-41/up1_remaining_gate_audit/report.md`  
Independent finding: `docs/implementation/AD-41/up1_remaining_gate_audit/independent_review_r1/report.md`

## Narrow correction

The original AD-41 report described AD41-W1 as creating an AD-40 receipt
repair. That is stale. AD-40 already has
`docs/implementation/AD-40/repository_design_source_authority_architecture/repair_r1/`
with the missing stdout/stderr/combined hashes, frozen input/output hashes,
PID/UTC/exit records, and final scoped rechecks. Its current manifest remains
`status=review_pending`, `accepted=false`, pending a different-Luna review.

AD41-W1 is therefore corrected to review and accept AD-40 `repair_r1`. A new
AD-40 `repair_r2` may be opened only if that independent review identifies a
concrete new defect. No unconditional repair round is scheduled.

All original authority conclusions remain unchanged: G1/G2 fresh
source-backed declaration, factory and identity receipts are absent;
`present=false`; T0/T1/T2, provider, mesh, solver, engineering, physical and
R01–R10 remain false; the 39-task DAG is unchanged; no candidate hash or
machine node is created by this repair.

## Corrected finite work-order sequence

| order | disposition | exact dependency and exit gate |
|---|---|---|
| AD41-W1 | immediately dispatchable | Different Luna independently reviews AD-40 `repair_r1/report.md`, `repair_r1/manifest.json` and its raw receipts. Pass requires the recorded receipt closure, frozen input/output hashes, exact path scope and all false claim flags to recheck. If a concrete defect is found, append a conditional AD-40 `repair_r2`; W1 remains open until that conditional repair is reviewed. |
| AD41-W2 | prepare only until W1 passes | RSDA G1/G2 payload authoring, in the exact G1/G2 product directories defined by the original AD-40 manifest. Inputs are the accepted AD-40 architecture, current source bytes, fresh public contracts and four axes. It emits canonical payload/authoring receipt or typed absence/failure, with no candidate hash, T0 join or execution. |
| AD41-W3 | prepare only until W2 is accepted | RSDA repository authority plus candidate binding/provenance. It consumes W2 products and emits the exact AD-40 authority-record and binding/provenance products. Same-candidate equality, four-axis provenance, missing=`terminal_deferred`, conflict=`fail_closed`; no T0/T1/T2 or physical edge. |
| AD41-W4 | wait for W3 | RSDA factory/declaration receipts and different-Luna fresh identity review. It emits the exact AD-40 factory, declaration, identity-review and same-candidate-join products. Source/declaration hashes must be recomputed from exact bytes; stale/foreign receipts fail closed; provider/mesh/solver/physical calls remain zero. AD-37 publication input and T0 remain later gates. |

The dependency semantics are now conditional and acyclic:

```text
AD40 repair_r1 review
  └─(only if concrete defect: conditional AD40 repair_r2, then review)
  └─> AD41-W2 payload authoring
      └─> AD41-W3 authority/binding/provenance
          └─> AD41-W4 factory/declaration/identity review
              └─> later AD37 publication input, then T0/T1/T2 gates
```

W1 does not recreate an already completed repair. W2–W4 are not dispatched by
this wording repair and cannot use a pending AD-40 repair as accepted
authority. The parent baseline, G3 realization/control/binding software
precursors and typed-absent T0 recheck remain local software evidence only;
their machine nodes stay `planned/proposal/accepted=false`.

## Validation and cleanup boundary

Only this `repair_r1/` directory is newly written. The original AD-41 report,
manifest, cleanup inventory, R1 independent review, AD-40 repair records,
core/task manifest, source, tests, fixtures, runs and historical receipts are
untouched. No Julia, DESC, provider, mesh, solver or physical command was
run. The task has no unrelated or temporary file to remove.
