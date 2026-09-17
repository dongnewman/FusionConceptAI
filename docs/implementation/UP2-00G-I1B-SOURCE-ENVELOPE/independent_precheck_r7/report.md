# G-I1B-A independent static precheck R7

Verdict: `ready_for_serial_focused`.

The preserved focused_r2 evidence records a real exit-1 test failure after the
runner reached the GI1B testset: 18 passed and 3 errored because the test
accessed `row.original.*` although `GI1BMutationEnvelopeRowV1` stores the
typed original at `row.binding.original`. R7 changes only those test accesses.
The final R7 test hash is `1b21a2afa6e8c6c11529831868c0fa15b0eeb73ad19b2def94a54530f9e41c36`,
matching `repair_r7/owned_hashes.json`'s after hash.

This independent review is static only. Julia, DESC, compiler, provider,
solver, mesh, and physical processes were not started. The final freeze is
HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`, with 3518
dirty porcelain entries, status snapshot SHA256
`10de92a1b5092eb2327cb0f5069cb62dce9a6a4b484bcbc11b8ac6c7f980e19c`, and
zero matching Julia/DESC processes. Only this R7 review directory was written.

The actual file is `test/GenomeV5/UP2/gi1b_source_envelope_tests.jl`; no
case-variant duplicate `GI1B_source_envelope_tests.jl` exists. The current
file has no remaining `row.original.` access. Lines `234`, `237`, and `255`
now use `row.binding.original.source_type`, `row.binding.original.value`, and
the same binding for type validation. The direct row hash fields
`row.original_hash` and `row.attempted_hash` remain unchanged.

Static checks confirm that the independent 50-row expected original/attempted
manifests and canonical hashes remain, with 50 IDs and paths checked. The
actual-A E1-present and E1/E2-absent factory calls remain, including source
identity, classification, N05 absence metadata, N06/N09/N10 gaps, and both
row-level and envelope-level compile/provider/solver counters equal to zero.
The public `row_builder` rejection and internal fault aggregate checks remain.

The repair is sufficient to authorize a new serial focused run. This review
does not erase or reinterpret focused_r2's failed run and grants no B00, B04,
physical, engineering, provider, mesh, or parent-goal credit.

