# G-I1B-A independent static precheck R2

Verdict: `changes_requested`.

This is an independent Luna/high static review of the repair-R2 source,
fixture, focused test, runner, and repair evidence. Julia and DESC were not
started. The repository freeze is HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`; the current dirty
worktree contains 3389 porcelain entries at this review boundary. The dirty
worktree and all protected inputs were preserved. This review does not grant
formal B04, B00, provider, mesh, engineering, physical, or parent-goal credit.

Repair R2 does add a real factory call using a constructed
`CandidateStatePackageV5`, actual E0, and G-I1A context. It exercises an
E1-present/E2-absent branch and an E1-absent/E2-absent branch, retains the
50-row matrix, adds runtime source-type checks, adds a typed E1-absence source
identity, and implements the requested aggregate status precedence. Those
changes address the four R1 findings at the implementation-presence level.

## Blocking findings

### GI1B-R2-01 — focused factory test has a deterministic leading-slash split failure (P1)

`test/GenomeV5/UP2/gi1b_source_envelope_tests.jl:103-106` computes the layer
with `first(split(spec.field_path, '/'))`. Every protected field path begins
with `/`. Julia's explicit-delimiter `split(str, delimiter)` uses
`keepempty=true` by default, so the first token is `""`; the next lookup is
`getproperty(envelope.outer_refs, Symbol(""))`. The factory test therefore
cannot reach its per-row assertions for the first non-N05 row. Use
`first(split(strip(spec.field_path, ['/']), '/'))` or
`first(split(spec.field_path, '/'; keepempty=false))`, then retain a test that
the layer is one of `:g1`, `:g2`, `:g3`.

### GI1B-R2-02 — 50-row assertions do not establish source-derived originals (P1)

`gi1b_source_envelope_tests.jl:94-114` checks the locator and declared type,
then checks `original_hash` and `attempted_hash` against hashes recomputed from
the row itself. It only calls `_gi1b_type_matches` when the row already has a
non-`nothing` value. There is no independent comparison of each
`row.original.value` with the corresponding field in the actual package,
actual E1 declaration, actual E0 context, or actual typed absence. A broken
accessor that returns `nothing`, or a wrong value with a self-consistent hash,
can pass this helper. Add independent expected-value assertions for all 50
rows in both factory branches, including the typed-absence expectation for
N05 and the actual N06/N09/N10 source fields.

### GI1B-R2-03 — real gap classifications and error retention remain untested (P1)

The factory source has explicit N06 typed-authority absence, N09 provider
deferred, and N10 fresh-receipt deferred branches at
`src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl:478-490`, and collects both
`fail_closed` and `program_exception` row paths at `:579-581`. The focused test
only tests aggregate precedence with synthetic symbols at
`gi1b_source_envelope_tests.jl:166-170`; it does not assert actual N06 rows
are `terminal_deferred` with the N06 gap, actual N09 rows are deferred with a
provider gap, N10-05 is deferred with a fresh-receipt gap, or that an actual
factory result preserves both a fail-closed row path and a program-exception
row path. Add source-bound row assertions and a controlled malformed-accessor
or exception-row case. Keep the aggregate assertion tied to the returned
envelope's `status` and `errors`, not only to a tuple of hand-written symbols.

### GI1B-R2-04 — exception-row source identity can fabricate a G1 fallback (P1)

`_gi1b_exception_row` catches any `_gi1b_source_identity` failure and falls
back to `context.g1_ref, context.g1_component_hash`
(`GI1BSourceMutationEnvelopeV1.jl:505-520`). A program-exception row for a G2,
G3, N05, or package source then carries a G1 identity, violating the
source-derived ref/hash contract exactly on the error path whose retention is
being tested. Remove the cross-layer fallback: retain a typed unavailable or
typed absence identity with the correct slot/layer, or return the actual
source identity when available and make the missing identity explicit. Add a
test that forces one row into `:program_exception` and verifies its ref/hash
and error path.

### GI1B-R2-05 — E1-absent identity omits the profile-hash assertion (P2)

The new absent branch checks content, schema, canonicalization, and
compatibility-profile hashes at `gi1b_source_envelope_tests.jl:155-161`, but
does not check `source_ref.profile_hash == absent_context.e1.profile_hash`.
Add that assertion so the required schema/canonical/profile/content identity
is independently covered. The implementation field exists on
`GI1BAbsentSourceIdentityV1`, and the branch no longer falls back to G3.

## Static QA and frozen inputs

JSON parsing of the fixture and repair-R2 evidence passed. The 50-row fixture
shape, unique IDs/paths, five rows per group, no-fixture-routing source scan,
planning validator, and targeted `git diff --check` passed. The source/test/
runner and all reviewed upstream inputs were SHA256-frozen in
`evidence_manifest.json`. A Julia base-source inspection confirmed the
explicit-delimiter `split` default used by GI1B-R2-01. The Julia/DESC process
sweep found zero matching processes. The focused Julia run remains intentionally
pending until the above blockers are repaired.
