# G-I1A R5 repair note

R4 independent review requested two narrow additions. R1--R4 receipts remain
immutable and the implementation remains `review_pending`/`accepted=false`.

1. `_gi1_overall_admission` is the shared pure summary helper used by the
   factory and schema-only tests. A typed E2-present slot with
   `e2_admission=:terminal_deferred` remains overall `terminal_deferred`.
   `declared_consistent` additionally requires both source admission states,
   valid slot/content identity, and an empty combined gap/error set. The
   synthetic present-slot branch is explicitly schema-only; current A still
   supplies no valid dimensioned N06 mapping and receives no source/physical
   credit.
2. `GI1ProgramException` classification is exercised through the trusted
   validator's actual factory path using an upstream N05 authority with
   `resolution=:program_exception`; the result is `program_exception` with
   zero downstream counters. Existing stale/foreign structural controls remain
   `ArgumentError`/`fail_closed`.

No external N06 source, physical law, provider, B04, engineering or R01-R10
claim is introduced. Julia/DESC was not run; independent static precheck is
required before any focused runtime.
