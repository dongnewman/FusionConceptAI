# G-I1B-A narrow repair R7

Status remains `review_pending`; `accepted=false`. This repair addresses only
the real `focused_r2` test failure recorded in the preserved
`focused_r2/qa.json` and its stdout/stderr/command/input-manifest evidence.
The failure occurred at the three test expressions that accessed
`row.original` even though `GI1BMutationEnvelopeRowV1` exposes the typed
original through `row.binding.original`. The row-level `original_hash` field
remains a direct row field and was retained.

The owned test now uses `row.binding.original.source_type`,
`row.binding.original.value`, and the same binding for the typed-value check.
A complete test-file scan found no remaining `row.original.` access. Existing
50-row coverage, independently derived original/attempted values and hashes,
classification assertions, and zero compile/provider/solver counter checks
were retained. No source, fixture, runner, core loader, or prior review/failure
evidence was changed.

R7 is static-only by instruction: Julia and DESC were not started. The
focused_r2 failure remains the evidence boundary; a different Luna R7
precheck is required before any serial focused rerun. No acceptance or parent
goal credit is claimed.
