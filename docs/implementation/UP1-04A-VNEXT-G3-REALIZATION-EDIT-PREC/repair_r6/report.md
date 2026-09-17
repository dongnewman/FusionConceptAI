# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC implementation repair R6

Date: 2026-09-15  
Status: `planned` / `proposal` / `accepted=false`; the independent focused_r3
postrun separated one contract-test expectation defect from one production
absence-reason classification defect.

## Bounded repair

Only the new realization source/test slice changed. The initial and current
state hash domains are now tested separately: the test asserts they differ and
recomputes each from its own complete canonical tuple. The production
`reason_for` path now performs an explicit zero/one/multiple classification for
each provenance slot: zero uses the existing default typed-absence reason, one
uses the supplied reason, and multiple produces a typed structural-conflict
reason. Source admission maps that conflict to `contract_admission=:fail_closed`
while retaining `physical_resolution=:unknown`. The test covers zero, one, and
multiple paths.

The source contains no remaining `first(generator, nothing)` pattern of this
class; the unrelated required source-port lookup remains a total-construction
lookup without a default. R3-R5 identity, hash, operation, status, source
body, and physical-boundary contracts remain in force. Old focused_r1/r2/r3
receipts remain preserved.

## Evidence boundary

This repair records static UTF-8/control-byte, hash, JSON, first-pattern,
plan/link, and scoped diff checks only. Julia, DESC, and focused execution are
not run in R6; a different Luna must precheck this repair. The node remains
`accepted=false`, contract/editability software only, with no provider, mesh,
engineering, physical, T0/T1, or R01-R10 completion credit.
