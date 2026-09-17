# M5 core performance R3 repair R5

R5 is a minimal test-only syntax repair after the R4 diagnostic parse failure.
The product sources and test intent are unchanged.  The immutable trace-owner
mutation negative now uses the valid `setfield!` call form instead of assigning
to `getfield(...)`.

The focused test was statically scanned for the same invalid `:symbol =` form
in function arguments or named-tuple construction; no additional occurrence
was found.  Julia was not run in this lane.

Status remains `screen_only / performance implementation pending runtime`.
The referenced R4 diagnostic remains a failure receipt only and carries no
formal DAG/stage credit or performance claim.
