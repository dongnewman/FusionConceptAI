# G-I1B-A narrow repair R5

Status remains `review_pending`; `accepted=false`. This repair answers the
single P1 finding in `independent_precheck_r4/report.md`. It is limited to the
owned G-I1B source, focused tests, and this `repair_r5/` directory. No Julia,
DESC, compiler, provider, solver, mesh, or physical process was started.

The public `gi1b_source_mutation_envelope` entry point now has only the
frozen `specs` keyword and always passes production `_gi1b_row`. It no longer
accepts a caller-supplied `row_builder`, so fabricated rows cannot bypass
actual source reads, typed accessors, source identities, or classifications.

The shared `_gi1b_build_rows` and `_gi1b_assemble_envelope` helpers remain in
the production module. Fault capture is available only through the explicitly
internal `_gi1b_source_mutation_envelope_with_row_builder` helper used by the
schema-only negative control. The focused test first proves that the public
keyword is rejected with `MethodError`, then uses the internal helper to
verify the controlled program-exception/fail-closed aggregate and error
retention. The ordinary public factory calls and all R4 independent original,
attempted, mutation-hash, counter, N05, N06, N09, and N10 assertions remain
unchanged in scope.

The R5 pre-edit freeze and final owned hashes are recorded in
`owned_hashes.json`; static receipts are in `static_qa.json`. This remains
contract/software evidence only and does not grant B00, B04, provider, mesh,
engineering, physical, or parent-goal status.
