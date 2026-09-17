# UP1 final integration independent review R2

## Decision

`pass_limited`. R1 finding `FI-R1-P1-001` is closed by the repaired
`conditional_schedule.json`. The repaired schedule now declares the complete
9-node route and all 8 adjacent transitions, with receipt-driven requirements
and explicit success/failure transitions for every stage.

## Independent checks

- W1/W2/W3/W4 latest independent reviews remain r7/r3/r4/r3 and
  `pass_limited`.
- Root still records exactly zero usable external inputs,
  `typed_absent -> terminal_deferred -> no_publish`, unchanged-input no-new-AD
  and no fresh S3 rerun, and no formal credit.
- The 39-node DAG, R01-R10, B00/B04, L4, parent goal and HEAD
  `b2c04d8339774635aaecd73651efcdb101e01b5d` remain preserved/open.
- The four handoff packets cover all 26 lossless W1/W2/W3 external absence
  IDs. Unknown owner/name/endpoint/authority values remain typed absence;
  `not_sent=true`, with no mutation, credentials or AD.
- The repaired handoff tree has 27 declared and actual files. Manifest and
  cleanup non-dynamic hashes match disk; all 18 dynamic raw streams are
  retained and accounted for by the cleanup dynamic map.
- Git hygiene remains read-only. The four unowned historical W1 raw streams
  remain `retain`; no deletion or source mutation was performed.

## Route acceptance

The repaired schedule declares:

`T0 -> authority_recheck -> T1 -> T2 -> aggregate -> UP2-00 -> UP1-04B -> UP1-04 -> UP2-01`

There are 8 adjacent transitions. Each stage has non-empty receipt/digest/hash
requirements, an explicit success transition, and an explicit failure
transition. Calendar dates are `not_assigned`; the package remains
`preparation_only`, `not_sent`, and `formal_credit=false`.

## Boundary

This is limited preparation evidence only. It does not accept external trust,
attestation, source authority, G2 evidence, environment provenance, S3,
numerical/engineering evidence, or any formal gate. No Julia, S3, DESC, mesh,
solver or external operation was run.
