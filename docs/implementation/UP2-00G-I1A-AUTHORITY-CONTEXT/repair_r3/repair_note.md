# G-I1A R3 repair note

R2 was returned for two bounded semantic defects.  This repair preserves the
R1 and R2 archives and changes only the G-I1A source/test/fixture boundary.

1. `GI1AuthorityContextV1` now validates package structural status through one
   mutually exclusive branch: `:valid` requires empty structural errors and
   `:fail_closed` requires a non-empty error tuple.  Both branches are directly
   exercised; contradictory status/error combinations remain rejected.
2. An explicit typed `N06SourceFieldLedgerMappingV1` is retained as a typed E2
   present slot when source admission is structurally consistent but
   `terminal_deferred`.  The context admission remains `terminal_deferred`,
   and the slot retains its mapping/content identity.  A missing N06 input
   still derives the actual-A absent/deferred slot.  Structural identity,
   candidate/E0 hashes, contract hashes, and mapping hash are rechecked at the
   slot boundary; invalid explicit mappings fail closed.  Deferred admission
   gaps are carried separately from the typed present slot, so context assembly
   does not dereference an absent-slot-only field.
3. The current A fixture still has no valid dimensioned G1-to-G3 law, so no
   source-backed E2-present positive or physical/provider claim is made.

Runtime Julia/DESC execution was not performed.  R3 remains
`review_pending`/`accepted=false` pending an independent static precheck.
