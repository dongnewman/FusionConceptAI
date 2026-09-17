# G-I1A R4 repair note

R3 was returned for admission classification boundaries.  This bounded repair
keeps all R1--R3 evidence immutable.

1. `gi1_admission_taxonomy` defines the four AD-26 software states without
   treating an unexpected symbol as a physical or provider result.
2. E0, package, E1, and N06 source validators now preserve
   `program_exception` through typed `GI1ProgramException`; expected source
   mismatches remain `ArgumentError`/fail-closed.  The trusted validator keeps
   the same distinction in its returned status.
3. Overall `contract_admission` is `declared_consistent` only when both slots
   are present, E2 admission is explicitly `:declared_consistent`, and the
   combined E0/E1/E2 gap set is empty.  A typed E2 present slot with deferred
   N06 authority therefore remains overall `terminal_deferred`.

The current A package still has no valid dimensioned N06 mapping.  No
source-backed E2-present positive, physical/provider, B04, or R credit is
claimed.  Julia/DESC was not run; R4 remains `review_pending`/`accepted=false`.
