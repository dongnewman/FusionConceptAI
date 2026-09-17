# G-I1B-A independent static precheck R3

Verdict: `changes_requested`.

This is an independent Luna/high static review of repair R3. Julia, DESC,
compiler, provider, solver, mesh, and physical processes were not started.
The freeze is HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`,
with 3408 current dirty porcelain entries and zero matching Julia/DESC
processes. Only this R3 review directory was written. The result carries no
B00, B04, physical, engineering, provider, mesh, or parent-goal credit.

R3 does address the R2 leading-slash failure, adds a direct-read expected
manifest for all 50 original values, adds actual N06/N09/N10 row assertions,
adds an unavailable source identity for exception rows, removes the G1
fallback, and asserts all E1-absence metadata hashes including `profile_hash`.

## Blocking findings

### GI1B-R3-01 — envelope-level downstream counters are still not tested (P1)

`gi1b_source_envelope_tests.jl:196` checks only each row's
`compile_calls/provider_calls/solver_calls`. The two returned envelopes are
never checked for `envelope.compile_calls == envelope.provider_calls ==
envelope.solver_calls == 0`, despite the envelope carrying those counters and
the constructor enforcing the zero contract. A regression in factory counter
aggregation could therefore pass this focused suite. Add the envelope-level
assertion for both E1-present/E2-absent and E1-absent/E2-absent results, plus
the exception result if it is materialized through the factory.

### GI1B-R3-02 — attempted values and mutation hashes remain self-validated (P1)

The independent manifest correctly supplies `row.original.value` from actual
package/E1/absence objects at `gi1b_source_envelope_tests.jl:89-163`, and the
test compares that value before checking hashes at `:181-195`. However,
`row.attempted.value` is never compared with an independent expected mutation,
`attempted_hash` is recomputed from that same returned value, and
`mutation_hash` is only checked to be a `Digest256` at `:197`. A broken
attempt mutator or mutation-hash payload can therefore remain self-consistent
and pass. Add a test-only attempted-value manifest (or explicit per-row
expected mutation values) and independently recompute both attempted and
canonical mutation hashes from the expected source, attempted value, binding,
error, path, and resolution.

### GI1B-R3-03 — factory `errors` retention is not exercised with a real exception row (P1)

The implementation now collects both `fail_closed` and `program_exception`
rows at `GI1BSourceMutationEnvelopeV1.jl:601-603`, and the direct helper case
at `gi1b_source_envelope_tests.jl:246-257` verifies an exception row and
aggregate precedence. That helper case never runs through
`gi1b_source_mutation_envelope`, so it does not verify that the factory's
returned `errors` tuple retains the exception path together with ordinary
fail-closed paths. Add a controlled factory invocation that makes one row
raise during row construction while another row is fail-closed, then assert
`status == :program_exception` and both exact `error_path:error_code` entries
are present in the returned envelope.

## Accepted R3 static points

The locator layer now strips leading slashes and uses `keepempty=false` at
`gi1b_source_envelope_tests.jl:185-188`, so it no longer creates
`Symbol("")`. The expected manifest reads package, E1-present declaration,
and E1-absent slot values directly and does not call
`_gi1b_actual_value`, `_gi1b_typed`, or `_gi1b_hash_typed` for extraction.
N06/N09/N10 row classification and gaps are asserted from the returned
factory rows. `GI1BUnavailableSourceIdentityV1` carries the layer marker and
the exception path no longer falls back to G1. N05 absent rows assert
content/schema/canonicalization/profile/compatibility metadata and content
source hash.

## Static QA and freeze

Fixture and R3 JSON parse checks passed; the 50-row fixture has unique IDs and
paths with five rows per N01-N10. The no-fixture-error-routing scan, planning
validator, targeted diff check, and zero-process sweep passed. The complete
R2 input inventory remains sealed by the R2 evidence manifest; this R3
manifest records the current protected hashes and R3 evidence hashes. A
focused Julia run remains pending until the three findings above are repaired.
