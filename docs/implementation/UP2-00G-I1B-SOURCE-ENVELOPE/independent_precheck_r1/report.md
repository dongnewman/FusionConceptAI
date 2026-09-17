# G-I1B-A independent static precheck R1

Verdict: `changes_requested`.

This is an independent Luna/high static review of the current G-I1B source,
fixture, focused test and runner. It did not start Julia or DESC. The repository
was frozen at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`,
with 294 pre-existing dirty-status lines. No file outside this new review
directory was modified.

The implementation has the expected 50 row specs, five rows per N01--N10,
unique IDs and paths, actual-A/E0/G-I1A identity fields, the repaired N05-05
endpoint-unit provenance hash, explicit typed E2 absence handling, N09 provider
deferred handling, N10 fresh-receipt/legacy-provenance gap text, attempted and
mutated hashes, and zero downstream counters. The source contains no fixture
expected-error routing. The frozen protected hashes match the R1 owned-hash
archive.

## Blocking findings

### GI1B-R1-01 — focused test never exercises the factory (P1)

`test/GenomeV5/UP2/gi1b_source_envelope_tests.jl:7-43` only parses the fixture,
counts row specs, checks hash helper return types, and checks text properties.
There is no actual `CandidateStatePackageV5`/E0/G-I1A construction and no call
to `gi1b_source_mutation_envelope`. The runner only includes this test
(`test/GenomeV5/UP2/run_gi1b_source_envelope.jl:5-8`). Therefore the focused
suite does not check actual typed originals or attempted values for any of the
50 rows, same-candidate refs/hashes/axes/context, E1 authored rows, typed E2
absence, N09/N10 classifications, mutation hashes, or zero invocation counters.
Add source-bound actual-A tests before a serial focused run, including E1
present/E2 absent and both-absent paths, with per-row assertions and tamper
controls. The fixture must remain oracle-only.

### GI1B-R1-02 — envelope status and errors hide row-level `fail_closed` (P1)

`src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl:492-496` sets the aggregate
status to `terminal_deferred` when any row is deferred, otherwise
`declared_consistent`; it only changes to `program_exception` for program
exception rows. The same block collects `errors` only from program exceptions.
Yet `_gi1b_status` returns `resolution=:fail_closed` for ordinary typed
contradiction rows at lines 427-431, and the constructor at lines 147-148
defines an explicit `fail_closed` status/error contract. A package/context with
only contradiction rows would therefore be labelled `declared_consistent`,
and a mixed envelope never exposes the fail-closed aggregate state. Aggregate
status/error accumulation must preserve `fail_closed` separately from
`terminal_deferred` and `program_exception`; row-level codes alone are not an
adequate substitute for the envelope contract.

### GI1B-R1-03 — declared source type is metadata-only (P2)

`_gi1b_typed` at `src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl:391-393`
wraps any returned value with `spec.source_type` without checking that the
actual value has the declared Julia type/shape. This allows a source accessor
to return an untyped or mismatched value while the row claims a typed original;
the focused tests do not catch it. Add a fail-closed source type/shape check
before wrapping and test a forged/malformed accessor boundary.

### GI1B-R1-04 — E1-absent N05 rows fall back to a G3 source identity (P1)

When `context.e1` is absent, `_gi1b_source_identity` falls through to
`_gi1b_ref`/`_gi1b_component_hash`
(`src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl:263-269,374-375`).
That gives the N05 authored-E1 rows the actual G3 outer ref/hash even though
their source locator is an E1 declaration and their value is a typed absence.
The envelope carries the E1 absent content hash only in slot metadata at
lines 499-502; the row binding does not preserve it. This conflates missing
E1 authority with a G3 source and can fabricate provenance for the absent
branch. Bind absent N05 rows to an explicit typed-E1-absence identity (or keep
the source ref/hash explicitly absent with the absence marker) and add a
both-absent test that asserts the row-level binding.

These findings are static software-contract blockers only. They do not change
the formal B04 boundary: B04, B00, provider, mesh, engineering, physical and
R01--R10 credit remain false. No Julia/DESC run was performed by this review.

## Static QA and frozen inputs

JSON/text parse checks passed for the current fixture, source matrix R2 copy,
independent-review manifest/QA, and the existing G-I1B evidence/input archives.
The 50-row source-spec count and no-fixture-routing scan passed. `git diff
--check` exited 0 with only pre-existing line-ending warnings. The planning
validator exited 0. The Julia/DESC process sweep found zero processes. Full
input hashes are in `input_hashes.json`; command outputs and exit codes are in
`command_receipts.json`; this review's evidence index is in
`evidence_manifest.json`.
